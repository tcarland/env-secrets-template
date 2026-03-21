env-secrets-template
====================

A template to serve as a project specific Secrets Managment solution.

The template pattern was created for managing project secrets as an 
Environment Configuration overlay.  This was born out of the need of a 
number of clients needing an immediate solution to managing secrets while 
modernizing platformms that could be considered agnostic to all environments, 
cloud or on-prem. Intended mostly as a stop-gap solution as those same 
clients had not yet settled on an official SecretsManager.

# Usage

The setup script is responsible for encrypting and decrypting files for a 
given environment and can sync the files in an overlay approach to the 
parent project. The setup uses *ansible-vault* to implement the encryption.

The `.pre-commit-hook.sh` script is used to ensure all files are encrypted.
This makes use of the python `pre-commit-hooks` project. The setup script 
will ensure that `pre-commit-hooks install` is run for a given local
repository.
