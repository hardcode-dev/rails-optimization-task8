# Case-study оптимизации

### оптимизация-1

**Сбор метрик:**
для начала я решил поискать какие то оптимизации бэка

выключил javascript в браузере и попробовал грузить сайт с открытой консолью, смотря в логи

потестил с помощью ab -n 10 -c 5 127.0.0.1:3000/
а также руками в браузере, просто обновлял страницу

результат ab
50% 17180 ms

результат теста руками
Completed 200 OK in 2805ms (Views: 2717.9ms | ActiveRecord: 33.4ms)
Completed 200 OK in 2792ms (Views: 2714.1ms | ActiveRecord: 8.6ms)
Completed 200 OK in 2406ms (Views: 2331.6ms | ActiveRecord: 10.0ms)
Completed 200 OK in 2836ms (Views: 2800.8ms | ActiveRecord: 10.7ms)

Т.е рендеринг занимает от 1.500ms до 2.000-2.500ms

- Фикс 1:
  В логах выделил для себя 4 запроса в базу, из них формируется меню.
  Меню статическое и никогда не меняется, удалил запросы, меню захардкодил в вьюхе.

- Фикс 2:
  Обнаружил лишнюю установку переменной и обращение к базе в set_main_menu, удалил.

- Фикс: 3:
  Для всего контента главной страницы добавляем кэширование, т.к контент статический и меняться будет только при деплое, то expores_in можно не устанавливать.

- Фикс 4:
  Добавить кэширование статических блоков

результат ab
50% 3809

Completed 200 OK in 730ms (Views: 724.3ms | ActiveRecord: 0.0ms)
Completed 200 OK in 1181ms (Views: 1140.9ms | ActiveRecord: 0.0ms)
Completed 200 OK in 671ms (Views: 664.3ms | ActiveRecord: 0.0ms)
Completed 200 OK in 619ms (Views: 612.1ms | ActiveRecord: 0.0ms)
Completed 200 OK in 609ms (Views: 603.1ms | ActiveRecord: 0.0ms)

Результат:
Ускорение время рендеринга страницы примерно в 3X раза.

- Фикс 5:
  Включил js, и обнаружил в консоли запросы к api, во первых отловил N+1 и решил их всех пофиксить
  Добавил обыкновенный includes где не хватало.

- Фикс 6:
  Добавить кэширование для запросов к апи

Processing by Api::V1::Blog::ArticlesController#index as JSON

```
до
Completed 200 OK in 511ms (Views: 412.3ms | ActiveRecord: 21.4ms)

после
Completed 200 OK in 127ms (Views: 115.7ms | ActiveRecord: 2.2ms)
```

Результат, прирост в 300 мс.

### оптимизация-2

Оптимизация js, css

- Фикс 1:

Сначала я решил воспользоваться инструментом coverage в Chrome,
сходу нашел лишний файл который загружается на главной, а нужен только на одной странице в админке.

Удаляю, результат: -198.315 kb

```
#= require froala_editor.min.js
```

- Фикс 2:
  Лишнее подключение ipanorama и все что с ним связанно:

Js

```
# Mount iPanorama (84 334 b + 9 072 b + 477 150 b + 143 b) =  - 570.699 kb !
#------------------------------------------------------------------------------
#= require jquery.ipanorama
#= require main
#= require three.min
#= require pixel
```

Css

```
 * iPanorama
 *-----------------------------------
 *= require effect
 *= require ipanorama
 *= require ipanorama.theme.default
 *= require ipanorama_style
```

- Фикс 3:
  Еще несколько лишних скриптов. Проверил, по коду, нигде нет вызовов. Удаляю.

```
#= require ion.rangeSlider
```

```
#= require jquery.formstyler
```

и файл где он вызывается тоже удаляю. Не нашел селекторов в проекте, устарел.

### оптимизация-3

- Фикс 1:
  Перевел сервер на HTTP/2 и настроил server-push.
  Большинство картинок перевел на server-push.
