# Case-study оптимизации
## О проекте
Данный проект является сервером для игры, клиент которого написан на js и c#

Сервер работает  в режиме API-Only. Ruby 2.3, Rails 5.0

Над этим проект работаю совсем недавно и с перфомансом тут дела не очень.
Какого-либо мониторинга тут нет
 
## Тесты
С тестами тут дела обстоят плохо. Их вообще перестали поддерживать, а также сами тесты, на мой взгляд, написаны достаточно неоптимальны, да и вообще, как-то непонятно =)

### Шаг №1
При запуске тестов, время выполнения составляло 24 секунды.
Просмотрев Gemfile, нашел database_cleaner. Зная, что у нас Rails 5(транзакционные тесты есть), а также, что нет тех кейсов, при которых было бы оправдано использование DatabaseCleaner.

Поэтому, первым делом, я везде убрал использование этого гема. Запустил тесты - тесты прошли успешно. Но помимо этого значительно возрасла скорость выполнения тестов

![first](https://i.ibb.co/94sQ8qJ/r-test-1.jpg)

То есть, теперь тесты выполняются 7 секунд, вместо 24. Сами тесты не упали, все работает так, как надо.
Иными словами, наличие ненужного, в данном случае, гема значительно тормозило работу тестов

### Шаг №2
Запустил профилировщик через RD_PROF.
Результат следующий

![second](https://i.ibb.co/9qpWjJw/r-test-2.jpg)

Самое критичное по времени это before each.

В процессе оптимизации, использование before_all и let_it_be удалось также восстановить тесты, которые были помечены, как pending(по причине их неработоспособности)

После внесение всех этих изменений, профилировщик выдал следующее

![third](https://i.ibb.co/c8BdCDY/r-test-3.jpg)

После, запускаем все тесты и смотрим на результат

![fourth](https://i.ibb.co/X5vvQPs/r-test-4.jpg)

Удалось добиться еще лучших результатов. С 7 секунд до 5

Тут есть место и для еще более лучшей оптимизации, но это потребует гораздо большего времени, так как необходимо вникнуь во всю логику тестов.
Чем я и займусь, но это, к сожалению, уже не попадет в ДЗ

## Приложение 
### Шаг №1
После переходим на непосредственно сам код
Поставил skylight и pg hero.

Оказывается, Dashboard Pg Hero не работает, если режим rails Api Only.
Можно было через консоль получать необходимые данные, через команды, что дает нам Pg Hero — но мне очень хотелось смотреть в дашборд =)
Поэтому я развернул чистый rails приложение, указал там подключение к нужной нам бд, установил PG Hero и нам нем я уже смотрел Dashboard

Так как проект Api Only, а также все экшены контроллеров принимают на вход обязательное json тело, были написаны rake таски на некоторые экшены

```
namespace :ab_test do
  namespace :users do
    task list: :environment  do

      api_field_one = 0
      api_field_two = 3
      session_key = 'some-session-key'
      auth_key = SocialMedia.generate_auth_hash(api_field_one, api_field_two, session_key)

      body = {
        api_uids: [2, 3],
        fields: ['level'],
        target_api_field: api_field_one,
        api_field_two: api_field_two,
        auth_key: auth_key,
        session: session_key,
        session_key: session_key
      }.to_json

      write_data_to_file(body)

      call_ab_test(link: 'users/list')
    end
  end

  def call_ab_test(link:)
    command = TTY::Command.new(printer: :quiet, color: true)
    
    command.run("ab -n 1000 -c 4 -T application/json -p #{Rails.root.join('tmp/data.json')} http://127.0.0.1:3001/#{link}")
  end
    
  def write_data_to_file(data)
    file_name = Rails.root.join('tmp/data.json')
    File.open(file_name, 'w') { |file| file.write(data) }
  end
```

Чтобы передавать тело в POST запрос через AB — необходимо передавать файл с содержимым json.
Сходу, отправлять данные через pipe и подхватывать через stdin - не вышло, поэтому, дабы не тратить время, был написан метод, который принимат тело и записывает его в файл json. Этот файл и передается в ab тест

В итоге, вызов bin/rake ab_test:users:list — вызывает ab с необходимыми параметрами по нужному нам роуту

Прогнав AB тесты по некоторым экшенам, и посмотрев в skylight — показало следующие результаты

![app_1](https://i.ibb.co/tcSKZ0d/r-app-1.jpg)

Видим, что, на данный момент, самый проблемный это EventsController#result
Более подробный результат

![app_2](https://i.ibb.co/tqr2ZnY/r-app-2.jpg)

Видим, что жалуется на большое кол-во аллокаций

Результаты AB теста
![app_3](https://i.ibb.co/3d1qT77/r-app-3.jpg)


Проанализировав этот контроллер, были обнаружены проблемы.
Например, бессмысленное использование dup у hash. Пример
```
default_fields.dup.merge(data: obj)
```

Также, создаем необходимый индекс, что советует PG_HERO

![app_4](https://i.ibb.co/vh41chS/r-app-4.jpg)

После исправления наиболее ярких проблем, результаты стали следующими

AB тестирование
![app_5](https://i.ibb.co/KjKhs92/r-app-5.jpg)

skylight
![app_6](https://i.ibb.co/J532b7J/r-app-6.jpg)

Как видим, почти на 200 штук меньше аллокаций. А также AB тесты показывают более лучший результат — 92 запроса в секунду против 88.
Время ответа 15ms против 17ms

### Шаг 2

Пробуем следующий роут

![app_7](https://i.ibb.co/cNKvfmC/r-app-7.jpg)


Также, PG Hero говорит о том, что нам нужен индекс
![app_8](https://i.ibb.co/BTQ7Ht4/r-app-8.jpg)

Но Skylight кроме того, что где-то есть проблема, толком ничего больше не говорит.
Поэтому решил воспользоваться профилировщиком RubyProf, чтобы попытаться локализировать проблему

Поставив RubyProf в middleware, удалось увидеть проблемы
![app_9](https://i.ibb.co/kMKwH6m/r-app-9.jpg)

В первых двух сходу что-то оптимизировать не удалось. Но вот в варианте SocialMedia идет получения уникального пользователя. Причем делается это запросом, ввида
```
User.where(api_field_one: value, api_field_two: value).first
```

Исправил эту запись, воспользовавшись методом ```find_by``` (данный метод делает выбору записи без использования ORDER BY)

Также, внес правки в ```User#as_json``` — там был переопределен этот метод с вызовом стокового `as_json`. Избавил от создания лишнего объекта 

В итоге, результат не сильно впечатляющий, но положительные изменения есть. Можно даже сказать, что эта оптимизация чувствуется

![app_10](https://i.ibb.co/Pz4gxSn/r-app-finish.jpg)

Было время ответа 83ms стало 78ms. Было создано 18,683 объектов, сейчас 16,842

### Шаг 3
Также, есть импорт с одной база данных в другую.
Реализовал его через Rails (добавил database_second.yml, rake таски, ввида `bin/rake second:db:migrate/rollback/create/drop` для работы со второй бд и т.д.)

Данные необходимо было перенести все, с предварительно обработкой. У второй бд немного отличается структура, а также другая структура jsonb полей.
В старой(откуда импортируем данные) бд есть обычные поля json (не jsonB) — и с этими полями надо работать — по сути, пытаемся парсить и искать в строке — тоже замедляло работу скрипта — но от этого никуда не деться

Изначально было решено используя LIMIT/OFFSET.
Написаны прямые SQL запросы к каждой таблице используя while

В итоге, получаем пачками и записываем в другую БД тоже пачками
Но способ был не очень быстрым. И тогда я решил переписать на where id > (какое-то число) LIMIT 10_000

Пример
```
// some code
while processed < total_worlds
  # PG::Result Object
  pg_result_object_worlds =
    ActiveRecord::Base.connection.execute(%(
      SELECT meta_worlds.id AS id, world_id AS type, static AS data, users.api_type AS api_type,
        users.api_uid AS api_uid, NOW() AS created_at, NOW() AS updated_at
      FROM meta_worlds
      INNER JOIN users ON worlds.user = users.id
      WHERE users.api_type = 2 AND meta_worlds.id > #{last_id}
      ORDER BY meta_worlds.id LIMIT #{step}
    ))

  values = pg_result_object_worlds.values.map! { |columns| "(#{columns.map! { |v| ActiveRecord::Base.connection.quote(v) }.join(', ')})" }
  fields = pg_result_object_worlds.fields
  cmd_tuples = pg_result_object_worlds.cmd_tuples

  pg_result_object_worlds.clear

  Second::World.connection.execute <<-SQL
    INSERT INTO worlds (#{fields.join(',')}) VALUES
    #{values.join(', ')}
  SQL

  last_id = Second::World.connection.execute(%(SELECT id FROM worlds ORDER BY id DESC LIMIT 1))[0]['id']

  processed += cmd_tuples

  print "\rtotal: #{total_worlds} | done: #{processed}"
end

// some code
```

И это выполнялось заметно быстрее. Но все равно долго.
Общее время выходило чуть больше 12 минут.

И после одного урока по оптимизации, где использовали потоковое чтение/запись с PG — я решил использовать этот способ
Переписал слегка запросы. Теперь мы потоково читаем и потоково пишем в другую БД

```
// some code here

f_connection = MetaWorld.connection_pool.checkout.raw_connection
s_connection = Second::World.connection_pool.checkout.raw_connection

# Convert from json to jsonb with new structure
convert_world_static_to_data = <<-SQL
  SQL HERE
SQL

# Some SQL
worlds_query =
  %(
    SELECT .... with Using convert_world_static_to_data
  )

f_connection.send_query(worlds_query)
f_connection.set_single_row_mode

worlds_command = <<-SQL
  COPY worlds (id, type, data, api_type, api_uid, created_at, updated_at) FROM STDIN with CSV DELIMITER ';' QUOTE '\b' ESCAPE '\\';
SQL

cn = 0

s_connection.copy_data(worlds_command) do
  f_connection.get_result.stream_each do |row|

    s_connection.put_copy_data(%(#{row['id']};#{row['type']};#{row['data']};#{row['api_type']};#{row['api_uid']};#{row['created_at']};#{row['updated_at']}\n))

    print "\rdone: #{cn += 1}"
  end
end

// some code here
```

И в итоге, весь импорт выполняется за 4.9 минуты.
Мало того, что потоковое чтение/запись работают быстрее, так еще избавились от тяжелых операций ORDER BY — они были нужны, для того, чтобы фильтровать по id

## Итого
Удалось улучшить результат, но в данном приложение достаточно сложно самому делать нужные запросы, ходить по роутам, соблюдать необходимые условия и, при необходимости, что-то комментировать/дописывать в коде, дабы отработать нужный сценарий

Тут, правильнее всего, поставить New Relic и PG Hero на продакшн. Чтобы собрались данные и отталкиваясь от полученных результатов, оптимизировать приложение 

