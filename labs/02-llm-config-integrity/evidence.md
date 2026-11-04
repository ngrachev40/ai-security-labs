# Выдержки вывода

[Описание исследования](README.md) · [Результаты CSV](results.csv) · [Скрипт](Start-VerifiedNeoBank.ps1)

Я привожу выдержки вывода эксперимента от **4 ноября 2026 года**, а не полный терминальный лог. Строки ниже подтверждают конкретные наблюдения; отсутствующие строки вывода и дословное приглашение чата я не восстанавливаю.

## Эталонный SHA256

Я экспортировал конфигурацию `neobank-lab` в `neobank-baseline.Modelfile` и рассчитал SHA256. Полученное значение:

```text
66EC48B1E589ABD150F61EEAEE7D47DE1D22FDA0F53963AEC81E56AF9A298CF9
```

Точные байты исходного экспорта в репозиторий не включены. По одному значению хэша я не могу восстановить этот файл или подтвердить совпадение с экспортом на другом компьютере.

## I01 — сравнение исходного файла и изменённой копии

После добавления комментария `# Integrity test: modified copy` я сравнил хэши на равенство:

```powershell
(Get-FileHash .\neobank-baseline.Modelfile).Hash -eq (Get-FileHash .\neobank-modified.Modelfile).Hash
```

Результат:

```text
False
```

## I02 — исходный файл и эталон

```powershell
(Get-FileHash -LiteralPath .\neobank-baseline.Modelfile -Algorithm SHA256).Hash -eq '66EC48B1E589ABD150F61EEAEE7D47DE1D22FDA0F53963AEC81E56AF9A298CF9'
```

Результат:

```text
True
```

## I03 — изменённая копия и эталон

```powershell
(Get-FileHash -LiteralPath .\neobank-modified.Modelfile -Algorithm SHA256).Hash -eq '66EC48B1E589ABD150F61EEAEE7D47DE1D22FDA0F53963AEC81E56AF9A298CF9'
```

Результат:

```text
False
```

## Политика выполнения PowerShell

Мой первый запуск `.ps1` остановила политика выполнения PowerShell. Это ограничение запуска скрипта, а не результат проверки SHA256; в пять проверок CSV я его не включаю. Затем я использовал `-ExecutionPolicy Bypass` для отдельного процесса `powershell`. Постоянную политику системы я не изменял. Дословный текст первоначальной ошибки здесь не привожу.

## I04 — отрицательный сценарий

Я запустил скрипт с изменённой копией:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\ai-security-lab\Start-VerifiedNeoBank.ps1" -ModelFile "$HOME\ai-security-lab\neobank-modified.Modelfile"
```

Фактический вывод:

```text
SHA256 mismatch. Model creation and launch blocked.
```

Я получил блокировку создания и запуска модели через скрипт.

## I05 — положительный сценарий

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME\ai-security-lab\Start-VerifiedNeoBank.ps1"
```

В выводе:

```text
Integrity check passed.
gathering model components
parsing GGUF
...
writing manifest
success
```

`...` обозначает пропущенные строки между выдержками, а не отдельную подтверждённую строку терминала. После успешной сборки у меня открылся чат `neobank-verified`. Я завершил его командой `/bye`. Дословное приглашение чата, длительность, потребление памяти и числовые коды завершения процессов в эти выдержки не включены.
