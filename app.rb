# app.rb
require 'dotenv/load'
require 'sinatra'
require 'sinatra/cors'
require 'mysql2'
require 'json'

set :port, ENV['PORT']

set :allow_origin, ENV['SPA_URL']
set :allow_methods, "GET,HEAD,POST,UPDATE,DELETE,OPTION"
set :allow_headers, "accept,content-type,if-modified-since"
set :expose_headers, "location,link"

client = Mysql2::Client.new(:host => ENV['DB_HOST'], :username => ENV['DB_USER'], :password => ENV['DB_PASS'], :database => ENV['DB_NAME'])

# Регулируемые параметры маршрутов
app_conf = { 
    # Количество записей на странице списка
    :PAGE_CAPACITY => 10
}


# Маршрут GET /list/:page
# 
# Список объектов на странице page списка объектов.
# 
# Отправляет JSON по схеме {count: *, list: [{id:, pay: {start:, end:}, title:, age:, seniority:, short_name:, phone_number:, description:}]}
get '/list/:page' do
    page = Integer(params['page'])
    start = (page - 1) * app_conf[:PAGE_CAPACITY]

    count = client.query("SELECT COUNT(*) from vacancy").to_a.first['COUNT(*)']
    vacancies = client.query("SELECT * from vacancy, teacher WHERE vacancy.teacher_teacher_id=teacher.teacher_id LIMIT #{start}, #{app_conf[:PAGE_CAPACITY]}")
    vacancies = vacancies.map do |row|
        { 
            id: row['vacancy_id'],
            pay: { start: row['fork_start'], end: row['fork_end'] },
            title: row['title'],
            age: Date.today.year - row['date_of_birth'].year,
            seniority: Date.today.year - row['career_start'],
            short_name: row['short_name'],
            phone_number: row['phone_number'],
            description: row['description']
        }
    end
    
    content_type :json
    { count: count, list: vacancies }.to_json
end

# Маршрут GET /read/:id
 # 
# Объект под номером id.
get '/read/:id' do
    id = Integer(params['id'])

    vacancy = client.query("SELECT * from vacancy, teacher WHERE vacancy_id=#{id} AND vacancy.teacher_teacher_id=teacher.teacher_id").to_a.first
    specialities = client.query("SELECT s.speciality_id, s.name from speciality AS s, teacher_has_speciality AS ths WHERE ths.teacher_teacher_id=#{vacancy['teacher_id']} AND s.speciality_id = ths.speciality_speciality_id")
    specialities = specialities.map do |row|
        [row['speciality_id'], row['name']]
    end
    all_specialities = client.query("SELECT s.speciality_id, s.name from speciality AS s").map do |row|
        [row['speciality_id'], row['name']]
    end

    content_type :json
    {
        title: vacancy['title'],
        pay: { start: vacancy['fork_start'], end: vacancy['fork_end'] },
        seniority: Date.today.year - vacancy['career_start'],
        career_start: vacancy['career_start'],
        description: vacancy['description'],
        phone_number: vacancy['phone_number'],
        email: vacancy['email'],
        telegram: vacancy['telegram'],
        full_name: vacancy['full_name'],
        short_name: vacancy['short_name'],
        age: Date.today.year - vacancy['date_of_birth'].year,
        date_of_birth: vacancy['date_of_birth'].strftime("%Y-%m-%d"),
        about: vacancy['about'],
        specialities: specialities,
        all_specialities: all_specialities,
        teacher_id: vacancy['teacher_id']
    }.to_json
end

# Маршрут GET /specialities
# 
# Возвращает список специальностей в виде пар "индекс-имя", доступный по полю all_specialities.
get '/specialities' do
    all_specialities = client.query("SELECT s.speciality_id, s.name from speciality AS s")
    all_specialities = all_specialities.map do |row|
        [row['speciality_id'], row['name']]
    end

    content_type :json
    { all_specialities: all_specialities }.to_json
end

# Маршрут DELETE /delete/:id
# 
# Удаляет объект с индексом id из списка вакансий.
delete "/delete/:id" do
    client.query("DELETE FROM vacancy WHERE vacancy_id=#{params['id']}")
    status 200
    'Success'
end

# Маршрут POST /create
# 
# Создает вакансию и учителя.
# 
# Данные передаются в теле запроса в формате JSON (см. SPA).
post "/create" do
    payload = JSON.parse(request.body.read)

    data = payload
    speciality_id = data['speciality_id']

    pay_start = data['pay']['start']
    pay_start = if pay_start.empty? then 'NULL' else pay_start end 

    pay_end = data['pay']['end']
    pay_end = if pay_end.empty? then 'NULL' else pay_end end 

    client.query("INSERT INTO teacher VALUES (DEFAULT, '#{client.escape(data['full_name'])}', '#{client.escape(data['short_name'])}', '#{data['date_of_birth']}', '#{client.escape(data['about'])}', '#{data['career_start']}', '#{data['phone_number']}', '#{data['email']}', '#{data['telegram']}')")
    teacher_id = client.last_id

    client.query("INSERT INTO vacancy VALUES (DEFAULT, #{pay_start}, #{pay_end}, '#{client.escape(data['title'])}', '#{client.escape(data['description'])}', #{speciality_id}, #{teacher_id})")
    vacancy_id = client.last_id

    client.query("INSERT INTO teacher_has_speciality VALUES (#{teacher_id}, #{speciality_id})")

    content_type :json
    { id: vacancy_id }.to_json
end

# Маршрут PUT /update/:id
# 
# Обновляет вакансию с индексом id
# 
# Данные передаются в теле запроса в формате JSON.
put "/update/:id" do
    payload = JSON.parse(request.body.read)

    data = payload
    vacancy_id = Integer(params['id'])

    client.query("UPDATE teacher SET full_name='#{client.escape(data['full_name'])}', short_name='#{client.escape(data['short_name'])}', date_of_birth='#{data['date_of_birth']}', about='#{client.escape(data['about'])}', career_start='#{data['career_start']}', phone_number='#{data['phone_number']}', email='#{data['email']}', telegram='#{data['telegram']}' WHERE teacher_id=#{data['teacher_id']}")
    client.query("UPDATE vacancy SET fork_start=#{pay_start}, fork_end=#{pay_end}, title='#{client.escape(data['title'])}', description='#{client.escape(data['description'])}', speciality_speciality_id=#{data['speciality_id']} WHERE vacancy_id=#{vacancy_id}")
    client.query("UPDATE teacher_has_speciality SET speciality_speciality_id=#{data['speciality_id']} WHERE teacher_teacher_id=#{data['teacher_id']}")

    content_type :json
    { id: vacancy_id }.to_json
end