# powershell_various
My repo for random powershell stuff

## Open-DirectoryAsIdeaProject.ps1
A way to open a project in IntelliJ IDEA from powershell or directly from windows explorer.

The script will open the latest IDEA version installed on the system.
- Given a file the file is opened in IDEA
- Given a directory the script looks for: .idea subdir or *.ipr or *.pom

Windows explorer integration:
- Run the script as admin with the -Install switch. You are now able to right click any directory in explorer and open it in IDEA.

Removing explorer integration:
- Run the script as admin with the -Uninstall switch.
