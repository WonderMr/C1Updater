powershell -NoProfile -File c:\dev\C1Updater\C1Updater.ps1 ^
-TargetBase targetbates ^
-TargetBaseServer targetserv ^
-TargetBasePort 1541 ^
-TargetBaseAgentPort 1540 ^
-PermissionCode 123 ^
-ApplyCFPath "c:\temp\1Cv8_demo.cf" ^
-UpdateByClientInTheEnd 1
rem -BaseUser 