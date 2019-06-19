# Raspberry-Pi Read Only FS

Modification of this single script to make it non-interactive.

## Use Case

To run on boot at rc.local for first boot setup.

Will write a file to the card before making it read only. So upon boot, if the file exists, the script will then exit.
