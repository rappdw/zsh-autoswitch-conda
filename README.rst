Autoswitch Conda
================

|GPLv3|

*zsh-autoswitch-conda* is a simple and quick ZSH plugin that switches conda
environments automatically as you move between directories.

* `How it Works`_
* `More Details`_
* Installing_
* Commands_
* `Customising Messages`_
* Options_
* `Security Warnings`_
* `Running Tests`_


How it Works
------------

Simply call the ``mkvenv`` command in the directory you wish to setup a
conda environment. A conda environment specific to that folder will
now activate every time you enter it.

``zsh-autoswitch-conda`` will try detect python projects and remind
you to create run this command if e.g. setup.py or requirements.txt is
found in the current directory.

See the Commands_ section below for more detail.

More Details
------------

Moving out of the directory will automatically deactivate the conda
environment. However you can also switch to a default python conda
environment instead by setting the ``AUTOSWITCH_DEFAULTENV`` environment
variable.

Internally this plugin simply works by creating a file named ``.venv``
which contains the name of the conda environment created (which is the
same name as the current directory but can be edited if needed). There
is then a precommand hook that looks for a ``.venv`` file and switches
to the name specified if one is found.

**NOTE**: you may want to add ``.venv`` to your ``.gitignore`` in git
projects (or equivalent file for the Version Control you are using).

Installing
----------

``autoswitch-conda`` requires conda or miniconda to be installed.

Once conda is installed, add one of the following lines to your ``.zshrc`` file depending on the
package manager you are using:

oh-my-zsh_

Copy this repository to ``$ZSH_CUSTOM/custom/plugins``, where ``$ZSH_CUSTOM``
is the directory with custom plugins of oh-my-zsh `(read more) <https://github.com/robbyrussell/oh-my-zsh/wiki/Customization/>`_:

::

    git clone "https://github.com/rappdw/zsh-autoswitch-conda.git" "$ZSH_CUSTOM/plugins/autoswitch_conda"

Then add this line to your ``.zshrc``

::

    plugins=(autoswitch_conda $plugins)
    
With latest conda installations placing conda initialization at the end of your .zshrc file, you'll need to move both your plugins and intialization of zsh to the bottom of your .zshrc file

**Manual Installation**

Source the plugin shell script in your `~/.zshrc` profile. For example

::

   source $ZSH_CUSTOM/plugins/autoswitch_conda/autoswitch_conda.plugin.zsh


Commands
--------

mkvenv
''''''

Setup a new project with conda autoswitching using the ``mkvenv``
helper command.

::

    $ cd my-python-project
    $ mkvenv
    Creating my-python-project conda environment
    Found a requirements.txt. Install? [y/N]:
    Collecting requests (from -r requirements.txt (line 1))
      Using cached requests-2.11.1-py2.py3-none-any.whl
    Installing collected packages: requests
    Successfully installed requests-2.11.1

``mkvenv`` will create a conda environment with the same name as the
current directory, suggest installing ``requirements.txt`` if available
and create the relevant ``.venv`` file for you.

Next time you switch to that folder, you'll see the following message

::

    $ cd my-python-project
    Switching conda: my-python-project  [Python 3.4.3+]
    $

If you have set the ``AUTOSWITCH_DEFAULTENV`` environment variable,
exiting that directory will switch back to the value set.

::

    $ cd ..
    Switching conda: mydefaultenv  [Python 3.4.3+]
    $

Otherwise, ``deactivate`` will simply be called on the conda environment to
switch back to the global python environment.

Autoswitching is smart enough to detect that you have traversed to a
project subdirectory. So your conda environment will not be deactivated if you
enter a subdirectory.

::

    $ cd my-python-project
    Switching conda: my-python-project  [Python 3.4.3+]
    $ cd src
    $ # Notice how this has not deactivated the project conda environment
    $ cd ../..
    Switching conda: mydefaultenv  [Python 3.4.3+]
    $ # exited the project parent folder, so the conda envrionment is now deactivated

rmvenv
''''''

You can remove the conda environment for a directory you are currently
in using the ``rmvenv`` helper function:

::

    $ cd my-python-project
    $ rmvenv
    Switching conda: mydefaultenv  [Python 2.7.12]
    Removing myproject...

This will delete the conda environment in ``.venv`` and remove the
``.venv`` file itself. The ``rmvenv`` command will fail if there is no
``.venv`` file in the current directory:

::

    $ cd my-non-python-project
    $ rmvenv
    No .venv file in the current directory!

disable_autoswitch_conda
'''''''''''''''''''''''''''''

Temporarily disables autoswitching of conda environments when moving between
directories.

enable_autoswitch_conda
''''''''''''''''''''''''''''

Re-enable autoswitching of conda environments (if it was previously disabled).

Customising Messages
--------------------

By default, the following message is displayed in bold when an alias is found:

::

    Switching %venv_type: %venv_name [%py_version]

Where the following variables represent:

* ``%venv_type`` - the type of virtualenv being activated (conda)
* ``%venv_name`` - the name of the conda environemnt being activated
* ``%py_version`` - the version of python used by the conda environment being activated

This default message can be customised by setting the ``AUTOSWITCH_MESSAGE_FORMAT`` environment variable.

If for example, you wish to display your own custom message in red, you can add the
following to your ``~/.zshrc``:

::

    export AUTOSWITCH_MESSAGE_FORMAT="$(tput setaf 1)Switching to %venv_name 🐍 %py_version $(tput sgr0)"

``$(tput setaf 1)`` generates the escape code terminals use for red foreground text. ``$(tput sgr0)`` sets
the text back to a normal color.

You can read more about how you can use tput and terminal escape codes here:
http://wiki.bash-hackers.org/scripting/terminalcodes


Options
-------

The following options can be configured by setting the appropriate variables within your ``~/.zshrc`` file.

**Setting a default conda environment**

You can set a default conda environment to switch to when not in a python project by setting
the value of ``AUTOSWITCH_DEFAULTENV`` to the name of a conda environment. For example:

::

    export AUTOSWITCH_DEFAULTENV="mydefaultenv"

**Default requirements file**

You may specify a default requirements file to use when creating a conda environment by
setting the value of ``AUTOSWTICH_DEFAULT_REQUIREMENTS``. For example:

::

    export AUTOSWITCH_DEFAULT_REQUIREMENTS="$HOME/.requirements.txt"

If the value is set and the target file exists you will be prompted to install with that file
each time you create a new conda environment.


**Set verbosity when changing environments**

You can prevent verbose messages from being displayed when moving
between directories. You can do this by setting ``AUTOSWITCH_SILENT`` to
a non-empty value.

Security Warnings
-----------------

zsh-autoswitch-conda will warn you and refuse to activate a conda
envionrment automatically in the following situations:

-  You are not the owner of the ``.venv`` file found in a directory.
-  The ``.venv`` file has weak permissions. I.e. it is writable by other users on the system.

In both cases, the warnings should explain how to fix the problem.

These are security measures that prevents other, potentially malicious
users, from switching you to a conda environment you did not want to
switch to.

Running Tests
-------------

Install `zunit <https://zunit.xyz/>`__. Run ``zunit`` in the root
directory of the repo.

::

    $ zunit
    Launching ZUnit
    ZUnit: 0.8.2
    ZSH:   zsh 5.3.1 (x86_64-suse-linux-gnu)

    ✔ _check_venv_path - returns nothing if not found
    ✔ _check_venv_path - finds .venv in parent directories
    ✔ _check_venv_path - returns nothing with root path
    ✔ check_venv - Security warning for weak permissions

NOTE: It is required that you use a minimum zunit version of 0.8.2


.. _oh-my-zsh: https://github.com/robbyrussell/oh-my-zsh

.. |GPLv3| image:: https://img.shields.io/badge/License-GPL%20v3-blue.svg
   :target: https://www.gnu.org/licenses/gpl-3.0
