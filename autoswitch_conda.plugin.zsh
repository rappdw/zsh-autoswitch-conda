export AUTOSWITCH_VERSION='1.10.0'

RED="\e[31m"
GREEN="\e[32m"
PURPLE="\e[35m"
BOLD="\e[1m"
NORMAL="\e[0m"


if ! type "conda" > /dev/null; then
    export DISABLE_AUTOSWITCH_VENV="1"
    printf "${BOLD}${RED}"
    printf "zsh-autoswitch-conda requires conda to be installed!\n\n"
    printf "${NORMAL}"
    printf "If this is already installed but you are still seeing this message, \n"
    printf "then make sure that conda is setup prior to loading this plugin (for conda) \n"
    printf "\n"
fi


function _python_version() {
    PYTHON_BIN="$1"
    if [[ -f "$PYTHON_BIN" ]]; then
        # For some reason python --version writes to stderr
        printf "%s" "$($PYTHON_BIN --version 2>&1)"
    elif type "python" > /dev/null; then
        printf "%s" "$(python --version 2>&1)"
    else
        printf "unknown"
    fi
}


function _autoswitch_message() {
    if [ -z "$AUTOSWITCH_SILENT" ]; then
        printf "$@"
    fi
}


function _maybeworkon() {
    local venv_name="$1"
    local venv_type="$2"
    local venv_dir="$CONDA_PREFIX/envs/$venv_name"

    local DEFAULT_MESSAGE_FORMAT="Switching %venv_type env: ${BOLD}${PURPLE}%venv_name${NORMAL} ${GREEN}[🐍%py_version]${NORMAL}"
    if [[ "$LANG" != *".UTF-8" ]]; then
        # Remove multibyte characters if the terminal does not support utf-8
        DEFAULT_MESSAGE_FORMAT="${DEFAULT_MESSAGE_FORMAT/🐍/}"
    fi

    if [[ -z "$VIRTUAL_ENV" || "$venv_name" != "$(basename $VIRTUAL_ENV)" ]]; then

        # TODO: base env won't be in the envs directory
        if [[ ! -d "$venv_dir" ]]; then
            printf "Unable to find ${PURPLE}$venv_name${NORMAL} conda env\n"
            printf "If the issue persists run ${PURPLE}rmvenv && mkvenv${NORMAL} in this directory\n"
            return
        fi

        conda activate "$venv_name"

        local py_version="$(_python_version "$venv_dir/bin/python")"
        local message="${AUTOSWITCH_MESSAGE_FORMAT:-"$DEFAULT_MESSAGE_FORMAT"}"
        message="${message//\%venv_type/$venv_type}"
        message="${message//\%venv_name/$venv_name}"
        message="${message//\%py_version/$py_version}"
        _autoswitch_message "${message}\n"

    fi
}


# Gives the path to the nearest parent .venv file or nothing if it gets to root
function _check_venv_path()
{
    local check_dir="$1"

    if [[ -f "${check_dir}/.venv" ]]; then
        printf "${check_dir}/.venv"
        return
    else
        # Abort search at file system root or HOME directory (latter is a perfomance optimisation).
        if [[ "$check_dir" = "/" || "$check_dir" = "$HOME" ]]; then
            return
        fi
        _check_venv_path "$(dirname "$check_dir")"
    fi
}


# Automatically switch conda env when .venv file detected
function check_venv()
{
    local SWITCH_TO=""

    # Get the .venv file, scanning parent directories
    local venv_path=$(_check_venv_path "$PWD")
    if [[ -n "$venv_path" ]]; then

        stat --version &> /dev/null
        if [[ $? -eq 0 ]]; then   # Linux, or GNU stat
            file_owner="$(stat -c %u "$venv_path")"
            file_permissions="$(stat -c %a "$venv_path")"
        else                      # macOS, or FreeBSD stat
            file_owner="$(stat -f %u "$venv_path")"
            file_permissions="$(stat -f %OLp "$venv_path")"
        fi

        if [[ "$file_owner" != "$(id -u)" ]]; then
            printf "AUTOSWITCH WARNING: Conda env will not be activated\n\n"
            printf "Reason: Found a .venv file but it is not owned by the current user\n"
            printf "Change ownership of ${PURPLE}$venv_path${NORMAL} to ${PURPLE}'$USER'${NORMAL} to fix this\n"
        elif ! [[ "$file_permissions" =~ ^[64][04][04]$ ]]; then
            printf "AUTOSWITCH WARNING: Conda env will not be activated\n\n"
            printf "Reason: Found a .venv file with weak permission settings ($file_permissions).\n"
            printf "Run the following command to fix this: ${PURPLE}\"chmod 600 $venv_path\"${NORMAL}\n"
        else
            SWITCH_TO="$(<"$venv_path")"
        fi
    elif [[ -f "$PWD/requirements.txt" || -f "$PWD/setup.py" ]]; then
        printf "Python project detected. "
        printf "Run ${PURPLE}mkvenv${NORMAL} to setup autoswitching\n"
    fi

    if [[ -n "$SWITCH_TO" ]]; then
        _maybeworkon "$SWITCH_TO" "conda"

    else
        _default_venv
    fi
}

# Switch to the default virtual environment
function _default_venv()
{
    if [[ -n "$AUTOSWITCH_DEFAULTENV" ]]; then
        _maybeworkon "$AUTOSWITCH_DEFAULTENV" "conda"
    elif [[ "$CONDA_DEFAULT_ENV" != "base" ]]; then
        _autoswitch_message "Deactivating: ${BOLD}${PURPLE}%s${NORMAL}\n" "$CONDA_DEFAULT_ENV"
        conda deactivate
    fi
}


# remove virtual environment for current directory
function rmvenv()
{
    if [[ -f ".venv" ]]; then
        local venv_name="$(<.venv)"

        # detect if we need to switch virtualenv first
        if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
            local current_venv="$CONDA_DEFAULT_ENV"
            if [[ "$current_venv" = "$venv_name" ]]; then
                _default_venv
            fi
        fi

#        printf "Removing ${PURPLE}%s${NORMAL}...\n" "$venv_name"
        conda env remove --name "$venv_name" --yes
        /bin/rm ".venv"
    else
        printf "No .venv file in the current directory!\n"
    fi
}


# helper function to create a conda environment for the current directory
function mkvenv()
{
    if [[ -f ".venv" ]]; then
        printf ".venv file already exists. If this is a mistake use the rmvenv command\n"
    else
        local venv_name="$(basename $PWD)"

        printf "Creating ${PURPLE}%s${NORMAL} conda environment\n" "$venv_name"

        # Copy parameters variable so that we can mutate it
        params=("${@[@]}")
        if [[ -n "$AUTOSWITCH_DEFAULT_PYTHON" && ${params[(I)--python*]} -eq 0 && ${params[(I)--no-default-packages]} -eq 0 ]]; then
            params+=("python=$AUTOSWITCH_DEFAULT_PYTHON")
        fi

        if [[ ${params[(I)--verbose]} -eq 0 ]]; then
            echo "conda create --name $venv_name $params"
            conda create --name $venv_name $params
        else
            echo "conda create --name $venv_name -q $params > /dev/null"
            conda create --name $venv_name -q $params > /dev/null
        fi

        printf "$venv_name\n" > ".venv"
        chmod 600 .venv

        _maybeworkon "$venv_name" "conda"

        install_requirements
    fi
}

function install_requirements() {
    if [[ -f "$AUTOSWITCH_DEFAULT_REQUIREMENTS" ]]; then
        printf "Install default requirements? (${PURPLE}$AUTOSWITCH_DEFAULT_REQUIREMENTS${NORMAL}) [y/N]: "
        read ans

        if [[ "$ans" = "y" || "$ans" == "Y" ]]; then
            pip install -r "$AUTOSWITCH_DEFAULT_REQUIREMENTS"
        fi
    fi

    if [[ -f "$PWD/setup.py" ]]; then
        printf "Found a ${PURPLE}setup.py${NORMAL} file. Install dependencies? [y/N]: "
        read ans

        if [[ "$ans" = "y" || "$ans" = "Y" ]]; then
            if [[ "$AUTOSWITCH_PIPINSTALL" = "FULL" ]]
            then
                pip install .
            else
                pip install -e .
            fi
        fi
    fi

    setopt nullglob
    for requirements in **/*requirements.txt
    do
        printf "Found a ${PURPLE}%s${NORMAL} file. Install? [y/N]: " "$requirements"
        read ans

        if [[ "$ans" = "y" || "$ans" = "Y" ]]; then
            pip install -r "$requirements"
        fi
    done

    install_conda_requirements
}

function install_conda_requirements()
{
    # Sample yml file can be found at
    # https://github.com/vithursant/deep-learning-conda-envs/blob/master/tf-py3p6-env.yml
    for requirements in *requirements.yml
    do
      printf "Found a %s file. Install using conda? [y/N]: " "$requirements"
      read ans

      if [[ "$ans" = "y" || "$ans" = "Y" ]]; then
        conda env update -f "$requirements"
      fi
    done
}

function enable_autoswitch_conda() {
    autoload -Uz add-zsh-hook
    disable_autoswitch_conda
    add-zsh-hook chpwd check_venv
}


function disable_autoswitch_conda() {
    add-zsh-hook -D chpwd check_venv
}


if [[ -z "$DISABLE_AUTOSWITCH_VENV" ]]; then
    enable_autoswitch_conda
    check_venv
fi
