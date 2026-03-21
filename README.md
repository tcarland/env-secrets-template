env-secrets-template
====================

A template to serve as a project specific Secrets Managment solution.

The template pattern was created for managing project secrets as an 
Environment Configuration overlay.  This was born out of the need of a 
number of clients needing an immediate solution to managing secrets while 
modernizing platformms that could be considered agnostic to all environments, 
cloud or on-prem. Intended mostly as a stop-gap solution as those same 
clients had not yet settled on an official SecretsManager.

As template repository, typically `git clone` is not used for cloning this 
repository. Instead, a new repository should be created defining the template 
repo. This can be done via the Github site or with the Github CLI.
```sh
gh repo create <new-repo-name> --template <OWNER/REPO> --clone
```

# Usage

The setup script is responsible for encrypting and decrypting files for a 
given environment and can sync the files in an overlay approach to the 
parent project. The setup uses *ansible-vault* to implement the encryption.

The `.pre-commit-hook.sh` script is used to ensure all files are encrypted.
This makes use of the python `pre-commit` project. The setup script 
will ensure that `pre-commit install` is run for a given local repository.

Typically a Python *virtualenv* is used to install python dependencies, 
provided as `requirements.txt`. The following is a simple example using
system python.
```sh
sudo apt install python3-venv python3-pip
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Environment Setup

The provided script, *env-secrets-setup.sh*, automates the decryption,
encryption, and the synchronization of files to a main project.
The script takes an *action* with a target environment name or
*envname* as parameters.
```sh
env-secrets-setup.sh [options] <action> [envname]
```

Use of *ansible-vault* requires an encryption secret be configured for the 
repository as `.ansible/.ansible_vault`. This can be modified via the 
provided *ansible.cfg*. This master secret is used for all encrypt|decrypt 
operations.


### Decrypt

The `decrypt` action requires a matching environment name to *./env/$envname*
and will decrypt all files under that path. Note that when encrypting and
decrypting files with *ansible-vault*, the re-encryption process will always
create a different result from git's perspective. The `restore` action will
revert all decryption to the previous (encrypted) versions from git, thus
any changes will require re-encrypting all files for the given environment.

### Encrypt

The `encrypt` action can optionally take an environment name and will only
encrypt files that are currently **not** encrypted. If no environment is
provided, the script will scan all environment files and encrypt any files
found unencrypted.

The action supports the `--dryrun` argument which will report the number of
unencrypted files without performing any encrypt operations. This makes the
action useful as a git *pre-commit* hook for ensuring that no secrets get
accidentally checked in to the repository.

A *pre-commit* script is provided as `.pre-commit-hook.sh` and is used by
the setup script to ensure it is installed to `.git/hooks` accordingly.

### Restore

As previously described, the `restore` action reverts all files under *env/*
to the current repository encrypted versions. Care should be taken as this
will undo any changes that have been made to the secrets. This action is
primarly used by the *sync* action and reduces the churn created by *encrypt*
always changing the file contents due to encryption and resulting in git changes.

### Sync

The `sync` action uses *rsync* to synchronize all environment files(secrets)
to the main project as defined by the provided `-R|--repopath` argument.

The action will first *decrypt* the environment files and then mirror the
assets from `env/$envname` to `$REPOPATH/env/$envname`, which of note, 
will delete any assets in the target that are not in the source path. 

Lastly, the *restore* action will revert the decrypted files once 
the *sync* is complete.

**WARNING**
Be sure to encrypt and commit all active changes PRIOR to running `sync`
as it will perform a `restore` action that could revert changes
(The setup script does check for outstanding changes and will WARN 
accordingly without running the restore.)
