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

## Архивная графика тем

Из архивов взяты только изображения. В приложение не входят старые
исполняемые файлы, SWF или код клиентов. Кадры вырезаны по границам ячеек;
у BMP фон с цветовым ключом `#ff00ff` переведён в прозрачность. Цветные
пиксели сохранены. Jimm и QIP также используют исходные многокадровые
GIF и задержки кадров. В GromitEmoticons (Mac 2011) и в наборе Pro 2003b
используются статические изображения.

- `Retro/jimm` — `micons.png` (16×16) и `smiles.png` (22×22) из
  [сохранённого JAR Jimm by XaTTaB 0.7.0b, MIDP2 RU](https://github.com/ALEXGREENCH/Jimm_mod_by_xattab_0.7.0b/tree/HEAD/preservation/wayback-originals/Jimm_MIDP2_RU).
  Коды проверены по `smiles.txt`. Все восемь статусов взяты из `icons.png`
  этого же JAR. Индексы 0–7 сверены по `statuses` и `imageIndexes` в `JimmUI.java`.
  Анимация взята из `res/MODULES/GIFSMILES/smiles` в архиве исходников XaTTaB.
  SHA-256 JAR
  `b57bc429ef0e1e8b5b5d07604622e668a3473bb266a91cb8a8ba0633183ec443`.
  Авторство Jimm Project, XaTTaB и авторов графики сохранено. `COPYING-Jimm.txt`
  взят из архива исходников этой модификации.
- `Retro/qip` — исходный скин `Skins/ICQ5` из
  [архива QIP 2005 build 7940](https://storage.fdo-files.com/nina/clients/qip/2005/zip/qip7940.zip).
  Кнопки из `allicons.bmp`, статусы из `statuses.bmp` (1, 2, 3, 4, 6, 7, 8, 10),
  смайлики из `Smilies/Static` и `Smilies/Animated`. Коды из `_define.ini`.
  Значки сверялись с меню оригинального клиента в
  [руководстве, рис. 6.9](https://files.znu.edu.ua/files/Bibliobooks/Inshi16/0011520.pdf#page=173).
  SHA-256 ZIP
  `e43a607d3b78b697f20bd3389066facd2a88de95783d934d846e5c8238a1a083`.
- `Retro/mac2011` — оригинальные изображения из `ICQOnAir.swf` и
  `loadable/emoticons/GromitEmoticons.swf` из
  [официального пакета ICQ for Mac 1.0.964](https://ftp.icq.com/pub/ICQ_Mac/icq4mac.air).
  Версия сверена по AIR-дескриптору. Для «Готов поболтать», N/A и «Занят»
  используются родственные изображения Available, Away и Busy из того же AIR:
  отдельных ресурсов этих статусов в пакете не найдено. SHA-256 AIR
  `0b203610d82c44aaf63fe7d4848412b02d034d3102dd42299da36100cea6570d`.
- `Retro/pro2003` — BMP 301–328 (выбранные 10 кадров) из `icquiex.dll`
  в [архиве набора ICQ 2003b build 3916](https://vrcp.ru/archive.html).
  SHA-256 DLL `4d8e5bd2b476ec16aa74a65a53d2d8a5fb23faadeb9d9e233d6ab068c139a55c`.
  Иконки профиля, истории, шрифта, панели смайликов и нескольких статусов
  извлечены непосредственно из `960StandardClient.emo` внутри
  [инсталлятора ICQ Pro 2003b build 3916](https://www.murb.com/download.php?id=3358).
  Смещения DIB в EMO: `d27421`, `d276a1`, `bcba11` (кадры 2 и 7),
  `d62639`, `dcd3c9`, `d7b671` (Away), `d7d2e1` (Occupied),
  `d7ef51` (Free For Chat), `d7c4a9` (DND), `d7e119` (N/A).
  Для «Невидимый» используется классический цветок с очками из
  [архива значков Licq, набор icq2](https://github.com/licq-im/licq/blob/master/qt-gui/share/icons/icq2/invisible.xpm),
  соответствующий выбранному снимку Pro; отдельный DIB в EMO не подтверждён.
  SHA-256 внешнего ZIP
  `016a78e7e8451833d6fb8fa0d8db3afd7285a1c29638aaaaec415fc7de1ba02b`.

В текущем оформлении используется набор смайликов Jimm. При отсутствии
отдельного ресурса у темы используется архивный ресурс Jimm.
