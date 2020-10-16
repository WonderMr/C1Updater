## Скрипт на PowerShell, что умеет обновлять загружать конфигурация в базу 1С
  * как из файла (ApplyCFPath), так и из хранилища(ConfigurationRepositoryF)
  * как для основной конфигурации, так и для расширения(Extension)
  * как с использованием доменной, так и парольной(BaseUser, BaseUserPass) авторизации
## Работает по следующем алгоритму  
  1. *Перед обновлением* завершает работу всех пользователей
  2. *Перед обновлением* может выполнить обработку WorkloadBeforeUpdatePath  
  3. *Перед обновлением* запомнит состояние работы РЗ и заблокирует их выполнение
  4. *Перед обновлением* блокирует базу случайным или указанным кодом(PermissionCode)
  5. **После обновления** применит конфигурацию
  6. **После обновления** восстановит сохранённое состояние работы РЗ
  7. **После обновления** может выполнить обработку WorkloadAfterUpdatePath
  8. **После обновления** может запустить выполнение обработчиков обновления конфигурации (UpdateByClientInTheEnd)
  9. **После обновления** разблокирует базу
### Список всех параметров
```
  TargetBase                            # имя целевой базы для обновления
  TargetBaseServer                      # имя сервера целевой базы для обновления
  TargetBasePort                        # порт сервера целевой базы, если отличается от стандартного то 1541
  TargetBaseAgentPort                   # порт агента сервера целевой базы, если отличается от стандартного то 1540
  PermissionCode                        # код разрешения доступа, если не указан, то устанавливается произвольный
  ApplyCFPath                           # путь к применяемому файлу конфигурации, если отсутствует, то просто применяем конфигурацию
  WorkloadBeforeUpdatePath              # имя обработки, выполняемой перед обновлением конфигурации. Если файла нет, пропускаем этап
  WorkloadAfterUpdatePath               # имя обработки, выполняемой перед обновлением конфигурации. Если файла нет, пропускаем этап
  BaseUser                              # имя пользователя для подключения к базе
  BaseUserPass                          # пароль пользователя для подключения к базе
  ConfigurationRepositoryF              # адрес хранилища конфигурации
  ConfigurationRepositoryN              # имя пользователя хранилища конфигурации
  ConfigurationRepositoryP              # пароль пользователя хранилища конфигурации
  Extension                             # имя расширения хранилища конфигурации
  ConfigurationRepositoryExtension      # для совместимости        
  UpdateByClientInTheEnd                # /C ЗапуститьОбновлениеИнформационнойБазы
 ```
## Примеры запуска:
#### Обновление базы basename на сервере serv конфигурацией из файла ApplyCFPath c:\1C\1cfv.cf под именем user с паролем pwd. База блокируется кодом 1, перед обновлением выполняется внешняя обработка отключения РИБ DistributedInfoBase_OFF.epf, после обновления - обработка c:\1C\DistributedInfoBase_ON.epf подключет РИБ
 ```
 powershell.exe -NoProfile -File c:\dev\C1Updater\C1Updater.ps1 ^
-TargetBase basename ^
-TargetBaseServer serv ^
-TargetBasePort 1541 ^
-TargetBaseAgentPort 1540 ^
-ApplyCFPath c:\1C\1cfv.cf ^
-PermissionCode 1 ^
-WorkloadBeforeUpdatePath c:\1C\DistributedInfoBase_OFF.epf ^
-WorkloadAfterUpdatePath c:\1C\DistributedInfoBase_ON.epf ^
-BaseUser user ^
-BaseUserPass pwd
```

#### Обновление расширения repo_ext в базе targetbase на сервере targetserv из привязанного к базе хранилища tcp://server:port/repo_name под именем repo_user и паролем repo_pwd. После применения конфигурации запускаем БСПшные обработчики обновления в конфигурации.
```
powershell -NoProfile -File c:\dev\C1Updater\C1Updater.ps1 ^
-TargetBase targetbase ^
-TargetBaseServer targetserv ^
-TargetBasePort 1541 ^
-TargetBaseAgentPort 1540 ^
-ApplyCFPath "c:\temp\1Cv8_demo.cf" ^
-ConfigurationRepositoryF tcp://server:port/repo_name
-ConfigurationRepositoryN repo_user
-ConfigurationRepositoryP repo_pwd
-Extension repo_ext
-UpdateByClientInTheEnd 1
```
