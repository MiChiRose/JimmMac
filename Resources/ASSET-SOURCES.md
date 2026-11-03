# Исходная графика

`ICQFlower.png` — классический логотип ICQ, автор и исходный источник ICQ.
Страница файла: https://commons.wikimedia.org/wiki/File:Logo_ICQ.png
Оригинал: https://upload.wikimedia.org/wikipedia/commons/d/df/Logo_ICQ.png
Датировка источника: 14 мая 2010. На Commons помечен PD-textlogo.

Графика включена по прямому запросу владельца JimmMac. Бренд ICQ сохраняет
свою принадлежность; JimmMac — отдельный клиент сети Jimm.online.
`JimmMac.icns` — упаковка этого же изображения в размеры и формат иконки macOS,
с сохранением пропорций и прозрачности. Сам логотип не перерисован.
С версии 0.7.1 ICNS пересобран штатным `iconutil` на Mavericks: присутствуют
малые форматы `is32`/`s8mk` и `il32`/`l8mk`, а также крупные и Retina-представления.
Системное чтение значка проверяется через `NSWorkspace`, включая обновление
регистрации установленного JimmMac в Launch Services.

## Ресурсы Jimm.online

Загружены 30 октября 2026 по прямому запросу владельца клиента с публичного сайта
https://jimm.online/. Оригинальные названия и файлы сохранены; принадлежность
графики и звуков остаётся у соответствующих авторов. Отдельная лицензия
в публичной разметке страницы не указана.

- `Sounds/message.mp3` — https://jimm.online/assets/jimm-sounds/message.mp3
- `Sounds/online.mp3` — https://jimm.online/assets/jimm-sounds/online.mp3
- `Sounds/offline.mp3` — https://jimm.online/assets/jimm-sounds/offline.mp3
- `Sounds/typing.mp3` — https://jimm.online/assets/jimm-sounds/typing.mp3
- `JimmStatusSprite.png` — https://jimm.online/assets/widget/jar/icons.png

Значки состояний используются из исходной полосы 16×16 без перерисовки.
Сопоставление состояний сверено с публичным кодом веб-клиента
https://jimm.online/build/assets/app.js: away 0, dnd 2, invisible 3,
occupied 5, offline 6, online 7. Сам код сайта в приложение не включён.

## Дополнительный корневой сертификат для GitHub API

`SectigoPublicServerAuthenticationRootE46.der` — публичный самоподписанный
Sectigo Public Server Authentication Root E46. Получен по HTTPS из
[ссылки на crt.sh](https://crt.sh/?d=4256644603), указанной в
[официальном списке Sectigo](https://www.sectigo.com/knowledge-base/detail/Sectigo-Public-Intermediates-and-Roots).
SHA-256 DER: `c90f26f0fb1b4018b22227519b5ca2b53e2ca5b3be5cf18efe1bef47380c5383`.

Также включён публичный `USERTrustECCCertificationAuthority.der`, необходимый
старому Security.framework для полной cross-signed цепочки сервера.
[Источник Sectigo](https://www.sectigo.com/knowledge-base/detail/Sectigo-Root-Certificates),
[сертификат](https://crt.sh/?d=2841410).
SHA-256 DER: `4ff460d54b9c86dabfbcfc5712e0400d2bed3fbc4d4fbdaa86e06adcd2a9ad7a`.

Корни используются только для проверки обновлений на `api.github.com`, дополняя
корневые сертификаты старой системы. Проверка hostname, срока действия и цепочки
остаётся включённой; системная Связка ключей не изменяется. Серверы API Jimm.online
и аватаров продолжают использовать обычное системное доверие.

Классические смайлики в `JMEmoticons.m` рисуются средствами AppKit внутри проекта.
