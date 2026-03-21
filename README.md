env-secrets-template
====================

As a software, data engineering consultant, I've come across a number of 
client platform environments that, in their journey of modernization, had 
not settled on a proper Secrets Manager. Maybe they used AWS to some degree, 
but given breadth of scale and platform, AWS or other solutions had not been
decided upon, and so they lacked a good solution for managing secrets.

I came across this pattern in a pinch to provide a client a kubernetes 
deployment that did not expose secrets in their github repository and instead
used a secondary repository that used `ansible-vault` to ensure that secret 
files were properly encrypted.

I've since abstracted the pattern as a repository template as I've used it 
a number of times since the original and this is that repo.


