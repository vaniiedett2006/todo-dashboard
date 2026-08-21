require 'webrick'
require 'json'

# WEBrick's mount_proc only wires up GET, POST, and PUT by default.
# This adds DELETE support so our /api/tasks endpoint can handle all four actions.
WEBrick::HTTPServlet::ProcHandler.class_eval do
  alias_method :do_DELETE, :do_GET
end

FILE_PATH = File.join(__dir__, 'tasks.json')
PUBLIC_DIR = File.join(__dir__, 'public')

# ---------- Data helpers ----------

def load_tasks
  return [] unless File.exist?(FILE_PATH)
  JSON.parse(File.read(FILE_PATH))
end

def save_tasks(tasks)
  File.write(FILE_PATH, JSON.pretty_generate(tasks))
end

# ---------- Web server setup ----------

# Hosting platforms assign a port via the PORT environment variable and
# expect the app to listen on 0.0.0.0 (not just your own computer).
# Locally, this still defaults to port 4567 on your own machine.
PORT = (ENV['PORT'] || 4567).to_i
BIND_ADDRESS = ENV['PORT'] ? '0.0.0.0' : '127.0.0.1'

server = WEBrick::HTTPServer.new(Port: PORT, DocumentRoot: PUBLIC_DIR, BindAddress: BIND_ADDRESS)

# Serve the dashboard homepage
server.mount_proc '/' do |req, res|
  res['Content-Type'] = 'text/html'
  res.body = File.read(File.join(PUBLIC_DIR, 'index.html'))
end

# GET /api/tasks -> return all tasks as JSON
server.mount_proc '/api/tasks' do |req, res|
  res['Content-Type'] = 'application/json'

  case req.request_method
  when 'GET'
    res.body = load_tasks.to_json

  when 'POST'
    # Add a new task
    data = JSON.parse(req.body)
    tasks = load_tasks
    tasks << { 'name' => data['name'], 'done' => false }
    save_tasks(tasks)
    res.body = tasks.to_json

  when 'PUT'
    # Toggle done status for a task by index
    data = JSON.parse(req.body)
    tasks = load_tasks
    index = data['index']
    if tasks[index]
      tasks[index]['done'] = !tasks[index]['done']
      save_tasks(tasks)
    end
    res.body = tasks.to_json

  when 'DELETE'
    data = JSON.parse(req.body)
    tasks = load_tasks

    if data['clearAll']
      # Wipe every task
      tasks = []
    else
      # Remove a single task by index
      index = data['index']
      tasks.delete_at(index) if tasks[index]
    end

    save_tasks(tasks)
    res.body = tasks.to_json
  end
end

trap('INT') { server.shutdown }

puts "Dashboard running! Open your browser to: http://localhost:4567"
server.start
