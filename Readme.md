# Выполнение

Сейчас я работаю на проекте, связанном с маркировкой товаров в России и СНГ. После создания нового закона о маркировке производители столкнулись с необходимостью
маркировать свою продукцию по определенным правилам (например, только теми штрих-кодами, которые выпускает уполномоченная организация, а также отчитываться перед этими или другими органами власти). У уполномоченной организации есть API. И вот, данный проект позволяет удобно аггрегировать информацию по продукции для производителей, составлять отчеты для органов контроля за выпуском и контрафактом. Иногда приходится еще другие API юзать, связанные с тематикой маркировки товаров.

Разрабатывается это все уже 2,5 года, проекта было два, вторая версия более расширенная.

С перформансом дела нормально, но тут нужно оговориться, что сейчас загруз не очень большой.

Из мониторинга есть PG Hero и стандартный Elastic Beanstalk мониторинг. Первая версия проекта крутится на Heroku, потому там свой мониторинг. Были бесплатные Skylight и NewRelic. Когда я только их начинал изучать, сейчас такого нет, к сожалению. В начале я мог бы их выпросить, но тогда я был еще совсем неопытный в таких делах, а сейчас это целая проблема - выпросить покупку такого оборудования.

Что оптимизировать в проекте:

- было бы круто порабоать с SQL-запросами, который касаются временных периодов. Некоторые из них довольно медленные и чем дольше период в запросе, тем хуже;
- фронт - очень много чего можно было бы сделать полезного - убрать лишнее, сжать что-то, там нет фреймворков, кроме bootstrap и jQuery. Фронт делал тоже я;
- тесты - сейчас занимаюсь этим, когда нет тасков, уже есть небольшие успехи.

Моя роль в проекте - я единственный разработчик на нем - таким образом - главный разработчик! В процессе приходили люди ненадолго в проект, делали таски по мере необходимости и уходили. Так что 95% сделал я.

Хотелось бы рассказать пару кейсов о работе на проекте. Случились они какое-то время назад, но там были моменты, которые мы проходили в курсе. Для рпешения проблем я применял то, что есть в курсе, хоть на тот момент про курс и не знал.

# Case 1 - RAM

Стояла задача создать систему формирования XML-отчетов. Делать такие отчеты было решено делать в фоне, создавая ParentJob, который дробил строчки отчета на группы и для каждой группы запускал дочернюю джобу. На первых этапах все вроде было номрмально, но потом heroku стал показывать потребление RAM heroku-воркера больше 100%, иногда намного больше. Случалось это, если делать отчет для выборки с сотней тысяч строк - выгрузка в память кучи записей. Конечно, там было неэкономно написано (код), как и полагается для неопытного разработчика и я несколько дней пытался профилировать этот вопрос и писать ленивую загрузку, но безуспещшно. Отчеты профайлеров (memory-profiler, кстати) были совершенно непонятны тогда, а слова "фидбек-луп" не существовало для меня в принципе.

Тут надо сказать, что до конца я так и не понял, что именно помогло, но в один прекрасный день, я нагуглил инфу про bloat-ы и что jemalloc, вроде, неплохо помогает с этим. Я добавил в heroku этот замечательный пакет и отметил кое-какие улучшения. Дальше втечение нескольких дней проблема ушла и по итогу, я думаю, что помогло все вместе. Jemalloc, переписывание кода на ленивую загрузку.

Не знаю, можно ли тут считать, сколько я сэкономил денег, ведь я же сам накосячил, а потом исправил. Можно было не исправлять, а попросить купить воркер за 250$/месяц (скорее всего заказчик бы меня послушал, но я не мог так с ним поступить). Но так как все обошлось и мы использовали за 50$, то можно сказать, что я сэкономил 200$ в месяц :).

# Case 2 - Ассоциации
Здесь я не использовал инфу из курса, но просто хочется написать.

Как-то я обнаружил, что удаление записи из таблицы занимает 16 секунд. Долго советовался с коллегами и искал, что может быть причиной такого поведения. Наконец обнаружил, что это constraint стоит в Postgres. Оказалось, что этот constraint триггерит проверку связанных таблиц, чтобы для связанных записей удалить эти связи. А потом было еще прикольней обнаружить, что этот constraint давно не используется и не нужен. С момента обнаружения такого долгого удаления до решения проблемы прошло несколько недель (занимался другими делами). Ну и после удаления констраинта все стало удаляться махом.

# Case 3 - Кейс про activerecord-import:

Я давно начал activerecord-import использовать для вставки нескольких записей в базу одним запросом. Но вот встала проблема. Такие запросы шли сплошным потоком по несколько штук в секунду. Они создавали родительскую запись обычным образом и потом шел Bulk insert дочерних элементов (в среднем 10-20 штук). На графике я увидел, что некоторые из них выполняются 2-3 секунды. Никакой системы не было в этом, случайные запросы просто долго выполнялись, большинство выполнялось быстро. Потом я услышал про PGHEro. Поставил его и первым же делом снес все ненужные индексы. Все - все запросы по вставке стали выполняться еще быстрее, чем до этого.

# Case 4 - Тесты (ДЗ 7)

Сейчас я занимаюсь оптимизацией тестов на проекте. Седьмое ДЗ делал на нем. Применил before_all, перенос let-ов в этот же блок, заменил create_list на activerecord-import и отключил DataBase Cleaner. Набор тестов, который выполнялся 140 секунд стал выполняться за 76.

Фидбек-луп здесь был примерно таким:

1) прогон тестов с помощью rspec-dissect/rspec --profile (иногда применял сэмплирование) с отсылкой времени выполнения в InfluxDB;
2) обнаружение самых долгих тестов
3) поиск причин долгого выполнения
4) правка неэкономных участков кода и переход к пункту 1)



# Задание №8

В этом задании вам нужно написать `case-study` о том как вы применили знания, полученные на курсе, к своим проектам.

## To start

Для начала напишите немного о своём проекте.

- что за проект
- как долго уже разрабатывается
- как дела с перформансом
- есть ли мониторинг
- можете ли вы навскидку предположить где в проекте есть что оптимизировать
- какова ваша роль в проекте, как давно работаете, чем занимаетесь

Сделайте `PR` в этот репозиторий, и дорабатывайте его по ходу курса.

## Hints

Форма `case-study` - свободная.

Можно написать в форме интересной технической статьи на Хабр. Потом можно будет и опубликовать.

Можно взять за основу форму `case-study` из первого задания.

### MVP is OK

Оптимизация не обязана быть доведена до прода.

Например, вы рассмотрели какую-нибудь подсистему с `fullstack` точки зрения и придумали как её оптимизировать, сделали `MVP`, получили первые результаты.

В таком случаем интересно рассказать об этом.


### О чём интересно рассказать

- расскажите об актуальной проблеме;
- расскажите, какой метрикой характеризуется ваша проблема;
- если вы работали в итерационном процессе оптимизации, расскажите как вы построили фидбек-луп;
- если пользовались профайлерами - опишите находки, которые сделали с их помощью;
- расскажите, как защитили достигнутый прогресс от деградации;
- прикиньте, сколько денег сэкономила ваша оптимизация: сократили потребление памяти и сэкономили денег на серверах / ускорили ответ сервера и уменьшили bounce-rate / ускорили прогон тестов и улучшили рабочий feedback-loop для всех участников команды...; если сделали что-то полезное, но сложно понять, как это оценить в деньгах, пишите в `Slack`, обсудим;
- если вы сделали много оптимизаций, расскажите о всех! чем больше - тем лучше! если какие-то из них менее интересны, упомяните о них обзорно;

### Если ничего не приходит в голову

Всегда можно оптимизировать тесты вашего проекта с помощью `test-prof`! (если конечно они уже не доведены до идеала)

Всегда можно сделать аудит проекта с помощью `sitespeed.io`, `webpagetest`, `pagespeed insights`, `lighthouse` и применить предложенные советы.

## Как сдать задание

Сделайте `PR` в этот репозиторий с вашим `case-study`.
