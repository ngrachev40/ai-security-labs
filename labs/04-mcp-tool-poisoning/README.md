# 04 — MCP: анализ Tool Poisoning и блокировка выдачи внутренней конфигурации

[Все исследования](../../README.md) · [Доказательства](evidence.md) · [Таблица результатов](results.csv) · [Точный патч](evidence/challenge2-resource-access.patch) · [Экспорт протокола исправленного сервера](evidence/inspector-protocol-dvmcp-challenge2-hardened-2026-11-09T10-09-38.475Z.json)

**Автор:** Nikita Grachev ([ngrachev40](https://github.com/ngrachev40)). **Дата эксперимента:** 9 ноября 2026 года.

## Цель и результат

Я развернул сторонний намеренно уязвимый стенд **DVMCP**, исследовал Challenge 2 и обнаружил инструкцию в метаданных инструмента, требующую раскрыть внутреннюю конфигурацию. Через MCP Inspector я вручную подтвердил доступность ресурса, изменил его обработчик и проверил запрет выдачи при сохранении расширенного поиска и публичной справки.

**LLM я к MCP в этих проверках не подключал.** Я подтвердил наличие Tool Poisoning в описании инструмента и возможность прямого чтения ресурса, но не автоматическое выполнение инъекции моделью, jailbreak или эксфильтрацию через ответ агента. Исходный сервер разработан не мной; моя работа — развёртывание, анализ, изменение обработчика и повторная проверка конкретного пути доступа.

## Окружение и версия стенда

| Параметр | Значение эксперимента |
| --- | --- |
| ОС / оболочка | Windows / Windows PowerShell 5.1 |
| Docker Desktop / Engine | 4.98.0 / 29.9.2 |
| Node.js | v26.13.0 |
| MCP Inspector | 2.14.0 |
| Python | Версию в этом эксперименте я отдельно не измерял |
| Upstream | [harishsg993010/damn-vulnerable-MCP-server](https://github.com/harishsg993010/damn-vulnerable-MCP-server) |
| Commit | `cdc4c6b5b76353203effcb26058e50fa6067d3a6` |
| Обработчик | `challenges/easy/challenge2/server.py` |
| Транспорт | Streamable HTTP |
| До изменения | `http://127.0.0.1:9002/mcp` |
| После изменения | `http://127.0.0.1:9102/mcp` |

## Развёртывание и воспроизведение

Я выполнял команды из корня отдельной копии DVMCP. Для воспроизведения я фиксирую ту же версию исходников:

```powershell
git clone https://github.com/harishsg993010/damn-vulnerable-MCP-server.git
cd damn-vulnerable-MCP-server
git checkout --detach cdc4c6b5b76353203effcb26058e50fa6067d3a6
docker build -t dvmcp .
```

Первый запуск у меня завершился `exec ./startup.sh: no such file or directory`. Файл существовал, но shebang заканчивался CRLF (`0d 0a`). Я перевёл `startup.sh` в LF и пересобрал образ. Это исправление совместимости Windows/Linux, а не защита от атаки. Для повторения нормализации:

```powershell
$startupPath = (Resolve-Path -LiteralPath .\startup.sh).Path
$startupText = [System.IO.File]::ReadAllText($startupPath).Replace("`r`n", "`n")
[System.IO.File]::WriteAllText($startupPath, $startupText, [System.Text.UTF8Encoding]::new($false))
docker build -t dvmcp .
docker run -d --name dvmcp-lab -p 127.0.0.1:9001-9015:9001-9015 dvmcp
npx.cmd @modelcontextprotocol/inspector
```

Имена контейнеров и порты для нового прогона должны быть свободны. В Inspector я выбрал Streamable HTTP и подключился к `http://127.0.0.1:9002/mcp`. Команды Docker привязывают опубликованные порты к loopback; host mounts, Docker socket и `privileged` я с ними не передавал. Исходный и исправленный контейнеры достигли `healthy`; отдельных скриншотов статуса контейнеров в кейсе нет. Это состояние запуска не является оценкой безопасности.

## Что я обнаружил до изменения

1. Через `tools/list` я получил `search_documents`, `enhanced_search`, `get_status`.
2. В описании `enhanced_search` я обнаружил ложную `IMPORTANT SYSTEM INSTRUCTION`: сначала прочитать `internal://secret_config`, затем включить всё содержимое в ответ под предлогом обязательного аудита. Это инструкция из недоверенных метаданных инструмента, а не настоящая системная инструкция клиента.
3. Я вызвал `search_documents` с `query="security"` и получил `security_policy` и `incident_response`. Начальная попытка со случайным переносом строки не нашла совпадений; я учитываю её как артефакт ввода, а не уязвимость.
4. `enhanced_search` с тем же запросом вернул те же два документа с relevance `2` и `1`. В самом ответе этого инструмента конфигурации и секретов не было.
5. В `resources/list` я увидел `get_secret_config` (`internal://secret_config`) и `get_search_help` (`docs://search_help`).
6. Я вручную выполнил `resources/read` для `internal://secret_config` и получил `flag`, `internal_api_key`, `database_url`, `stripe_secret`, `encryption_key`. Я сопоставил значения с константами `_SECRET_CONFIG` в зафиксированном исходном коде: это демонстрационные данные DVMCP, а не реальные скомпрометированные банковские или платёжные ключи.
7. Я проверил `get_secret_config`: исходное тело функции не проверяло доступ. Надпись `authorized access only` в docstring не ограничивала чтение.

![Описание enhanced_search с ложной системной инструкцией и требованием прочитать внутренний ресурс](screenshots/01-tool-description.png)

На снимке я зафиксировал Tool Poisoning в описании `enhanced_search`. Это доказательство наличия инструкции, а не её исполнения моделью.

![До изменения ручное чтение internal://secret_config возвращает конфигурацию DVMCP](screenshots/04-baseline-config.png)

До изменения я получил конфигурацию прямым вызовом ресурса через Inspector. Видимые значения — демонстрационные константы исходного стенда; я сохранил их без маскирования, чтобы результат оставался проверяемым.

## Точный патч

Я изменил только docstring и тело `get_secret_config`; [приложенный патч](evidence/challenge2-resource-access.patch) сохранён без изменений. Вместо формирования ответа из `_SECRET_CONFIG` обработчик теперь содержит:

```python
    """Internal configuration is not exposed by the search service."""
    raise PermissionError("Access denied: internal configuration is not available")
```

Это **безусловный запрет выдачи ресурса всем клиентам поискового сервиса**, а не ролевая авторизация. Ресурс остаётся видимым в `resources/list`, но его чтение завершается ошибкой. Константы конфигурации остаются в исходниках и образе. Инъекцию в описании `enhanced_search` я намеренно оставил, чтобы проверить независимое ограничение возможностей на сервере.

Для применения патча в отдельной копии DVMCP на указанном commit:

```powershell
$resourcePatch = Read-Host 'Полный путь к challenge2-resource-access.patch из ai-security-labs'
git apply --check -- $resourcePatch
git apply -- $resourcePatch
python -m py_compile challenges/easy/challenge2/server.py
docker build -t dvmcp-hardened .
docker run -d --name dvmcp-hardened-lab -p 127.0.0.1:9102:9002 dvmcp-hardened
```

В эксперименте проверка синтаксиса прошла. После сборки я подключил Inspector к `http://127.0.0.1:9102/mcp`. Суффикс `hardened` — выбранное мной имя образа и подключения; он не означает, что весь DVMCP защищён.

## Повторная проверка и таблица до/после

| ID | Фаза | Проверка | Ожидал | Получил | Статус |
| --- | --- | --- | --- | --- | --- |
| M01 | До | Описание инструмента без внедрённой инструкции | no_embedded_instruction | embedded_instruction_present | FAIL |
| M02 | До | `search_documents`, `query="security"` | security_policy_and_incident_response | security_policy_and_incident_response | PASS |
| M03 | До | `enhanced_search`, `query="security"` | documents_with_relevance_2_and_1 | documents_with_relevance_2_and_1 | PASS |
| M04 | До | Чтение `internal://secret_config` | access_denied | configuration_returned | FAIL |
| M05 | До | Чтение `docs://search_help` | public_help_returned | public_help_returned | PASS |
| M06 | После | Чтение `internal://secret_config` | access_denied | access_denied | PASS |
| M07 | После | `enhanced_search`, `query="security"` | documents_with_relevance_2_and_1 | documents_with_relevance_2_and_1 | PASS |
| M08 | После | Чтение `docs://search_help` | public_help_returned | public_help_returned | PASS |

Я сохранил эти наблюдения в [results.csv](results.csv) со ссылками на доказательства. `PASS` относится к конкретному ожидаемому результату; общий процент безопасности по разным проверкам я не рассчитываю. После изменения обычный `search_documents` отдельно не проверялся; повторная проверка поиска относится к `enhanced_search`. Отдельного вызова `get_status` я здесь не заявляю.

![После изменения resources/read возвращает Access denied без конфигурации](screenshots/07-denied-config.png)

Я получил JSON-RPC error: `Error reading resource internal://secret_config: Access denied: internal configuration is not available`. Полей конфигурации в этом ответе нет. Это серверный отказ, а не отказ LLM.

![После изменения enhanced_search возвращает прежние два документа с relevance 2 и 1](screenshots/08-hardened-search.png)

Я проверил сохранность расширенного поиска: вернулись `security_policy` и `incident_response` с теми же оценками `2` и `1`. Успешное чтение публичной справки после изменения показано в [доказательствах](evidence.md#m08).

## Протокол и приватность

В [экспорте Inspector](evidence/inspector-protocol-dvmcp-challenge2-hardened-2026-11-09T10-09-38.475Z.json) я проверил **9 записей: 8 запросов и 1 notification**. Это `initialize`, `notifications/initialized`, четыре запроса списков и три контрольных вызова. Запросы с JSON-RPC ID `5`, `6`, `7` подтверждают соответственно запрет конфигурации, успешный `enhanced_search` и публичную справку. Экспорт относится **только к исправленному серверу**, а не к испытаниям обеих версий. Исходное поведение я подтверждаю скриншотами и анализом upstream-кода.

Я просмотрел все девять скриншотов и JSON перед публикацией. Личных имён, персональных путей, реальных токенов Inspector, адресных строк с токенами или реальных секретов я не обнаружил; маскирование не понадобилось. Демонстрационные значения на снимке 04 совпадают с константами upstream. Числовые `progressToken` в протоколе — метки прогресса запросов, а не токены доступа Inspector. Изображения, патч и JSON в кейсе сохранены побайтово; технические доказательства не перерисовывались.

## Ограничения и вывод

- Я не подключал LLM и не доказал автоматическое выполнение инъекции, jailbreak или утечку через ответ агента.
- Tool Poisoning в метаданных остаётся: я ограничил доступный серверный ресурс, а не удалил внедрённый текст.
- Запрет действует на конкретный обработчик `get_secret_config` и одинаков для всех клиентов. Аутентификацию и роли я этим патчем не реализовал.
- Константы остались в исходниках и образе. Патч не защищает чтение файлов, доступ к образу или другие challenges DVMCP.
- Имена `dvmcp-hardened` и `dvmcp-hardened-lab`, успешная сборка и `healthy` не доказывают безопасность всего стенда.
- Я не представляю работу как коммерческий аудит, исследование production-системы или новый zero-day. Число повторов и статистику успешности по этим материалам не устанавливаю.
- Общие принципы минимальных возможностей, независимых проверок и регулярного тестирования я использую как направление дальнейшей работы, а не как измеренные результаты. Эксперименты с весами, alignment и влиянием размера модели здесь не проводились.

Я подтвердил, что текстовая пометка о закрытом доступе не заменяет серверное ограничение возможностей. Я воспроизвёл прямую выдачу ресурса, запретил её и проверил сохранность расширенного поиска и публичной справки.

## Проверки публикации и источники

При подготовке материалов я отдельно проверил точность патча, его применимость к upstream-файлу зафиксированного commit и синтаксис исправленной копии. Я сверил JSON, таблицу результатов, ссылки и изображения. Эти проверки артефактов не являются повторным развёртыванием контейнеров или новым прогоном Inspector; Docker, MCP-сервер и LLM при подготовке публикации я не запускал.

- [DVMCP — исходный сторонний стенд](https://github.com/harishsg993010/damn-vulnerable-MCP-server).
- [Зафиксированная версия исходников](https://github.com/harishsg993010/damn-vulnerable-MCP-server/tree/cdc4c6b5b76353203effcb26058e50fa6067d3a6).
- [Challenge 2: server.py в указанной версии](https://github.com/harishsg993010/damn-vulnerable-MCP-server/blob/cdc4c6b5b76353203effcb26058e50fa6067d3a6/challenges/easy/challenge2/server.py) — константы, описания инструментов и исходный обработчик ресурса.
