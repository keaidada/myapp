import Foundation

struct ServiceTemplate: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var category: String
    var icon: String
    var kind: ServiceKind
    var appPath: String?
    var url: String?
    var command: String?
    var checkURL: String?
    var statusCommand: String?
    var startCommand: String?
    var stopCommand: String?
    var restartCommand: String?
    var pidPattern: String?
    var description: String?

    func makeService() -> ManagedService {
        ManagedService(
            name: name,
            category: category,
            icon: icon,
            kind: kind,
            appPath: appPath,
            url: url,
            command: command,
            checkURL: checkURL,
            statusCommand: statusCommand,
            startCommand: startCommand,
            stopCommand: stopCommand,
            restartCommand: restartCommand,
            pidPattern: pidPattern,
            sortOrder: 0
        )
    }
}

enum ServiceTemplates {
    static let all: [ServiceTemplate] = [
        // ── Homebrew 服务 ──
        .init(name: "nginx", category: "Homebrew", icon: "globe", kind: .command,
              command: "brew services start nginx",
              checkURL: "http://localhost:8080",
              statusCommand: "brew services list | grep '^nginx' | grep -q started",
              startCommand: "brew services start nginx",
              stopCommand: "brew services stop nginx",
              restartCommand: "brew services restart nginx",
              pidPattern: "nginx",
              description: "Web 服务器（默认 8080，可在 nginx.conf 修改）"),
        .init(name: "redis", category: "Homebrew", icon: "server.rack", kind: .command,
              command: "brew services start redis",
              checkURL: "http://localhost:6379",
              statusCommand: "brew services list | grep '^redis' | grep -q started",
              startCommand: "brew services start redis",
              stopCommand: "brew services stop redis",
              restartCommand: "brew services restart redis",
              pidPattern: "redis-server",
              description: "内存数据库（端口 6379）"),
        .init(name: "postgresql", category: "Homebrew", icon: "cylinder.split.1x2", kind: .command,
              command: "brew services start postgresql@16",
              checkURL: "http://localhost:5432",
              statusCommand: "brew services list | grep '^postgresql' | grep -q started",
              startCommand: "brew services start postgresql@16",
              stopCommand: "brew services stop postgresql@16",
              restartCommand: "brew services restart postgresql@16",
              pidPattern: "postgres",
              description: "关系型数据库（端口 5432）"),
        .init(name: "mysql", category: "Homebrew", icon: "cylinder.split.1x2", kind: .command,
              command: "brew services start mysql",
              checkURL: "http://localhost:3306",
              statusCommand: "brew services list | grep '^mysql' | grep -q started",
              startCommand: "brew services start mysql",
              stopCommand: "brew services stop mysql",
              restartCommand: "brew services restart mysql",
              pidPattern: "mysqld",
              description: "关系型数据库（端口 3306）"),
        .init(name: "mongodb-community", category: "Homebrew", icon: "leaf", kind: .command,
              command: "brew services start mongodb-community",
              checkURL: "http://localhost:27017",
              statusCommand: "brew services list | grep '^mongodb' | grep -q started",
              startCommand: "brew services start mongodb-community",
              stopCommand: "brew services stop mongodb-community",
              restartCommand: "brew services restart mongodb-community",
              pidPattern: "mongod",
              description: "文档数据库（端口 27017）"),
        .init(name: "elasticsearch", category: "Homebrew", icon: "magnifyingglass", kind: .command,
              command: "brew services start elasticsearch",
              checkURL: "http://localhost:9200",
              statusCommand: "brew services list | grep '^elasticsearch' | grep -q started",
              startCommand: "brew services start elasticsearch",
              stopCommand: "brew services stop elasticsearch",
              restartCommand: "brew services restart elasticsearch",
              pidPattern: "elasticsearch",
              description: "搜索与分析引擎（端口 9200）"),
        .init(name: "rabbitmq", category: "Homebrew", icon: "arrow.triangle.branch", kind: .command,
              command: "brew services start rabbitmq",
              checkURL: "http://localhost:15672",
              statusCommand: "brew services list | grep '^rabbitmq' | grep -q started",
              startCommand: "brew services start rabbitmq",
              stopCommand: "brew services stop rabbitmq",
              restartCommand: "brew services restart rabbitmq",
              pidPattern: "rabbitmq",
              description: "消息队列（管理台 15672）"),
        .init(name: "memcached", category: "Homebrew", icon: "memorychip", kind: .command,
              command: "brew services start memcached",
              checkURL: "http://localhost:11211",
              statusCommand: "brew services list | grep '^memcached' | grep -q started",
              startCommand: "brew services start memcached",
              stopCommand: "brew services stop memcached",
              restartCommand: "brew services restart memcached",
              pidPattern: "memcached",
              description: "缓存服务（端口 11211）"),

        // ── Docker ──
        .init(name: "Docker Compose 项目", category: "Docker", icon: "shippingbox", kind: .command,
              command: "docker compose up -d",
              statusCommand: "docker compose ps -q | grep -q .",
              startCommand: "docker compose up -d",
              stopCommand: "docker compose down",
              restartCommand: "docker compose restart",
              pidPattern: "docker",
              description: "在当前目录运行 docker compose 项目"),
        .init(name: "Docker 单容器", category: "Docker", icon: "shippingbox", kind: .command,
              command: "docker run -d --name myapp -p {port}:80 nginx",
              checkURL: "http://localhost:{port}",
              statusCommand: "docker ps -q --filter name=myapp | grep -q .",
              startCommand: "docker start myapp",
              stopCommand: "docker stop myapp",
              restartCommand: "docker restart myapp",
              pidPattern: "myapp",
              description: "模板变量 port=8080，可改镜像名"),

        // ── 开发 ──
        .init(name: "Next.js 开发服务器", category: "开发", icon: "bolt", kind: .command,
              command: "npm run dev",
              checkURL: "http://localhost:3000",
              statusCommand: "pgrep -f 'next dev' | grep -q .",
              pidPattern: "next",
              description: "前台命令（30 秒超时），建议配 launchd/brew services 常驻"),
        .init(name: "Vite 开发服务器", category: "开发", icon: "bolt", kind: .command,
              command: "npm run dev",
              checkURL: "http://localhost:5173",
              statusCommand: "pgrep -f vite | grep -q .",
              pidPattern: "vite",
              description: "前台命令（30 秒超时），建议配 launchd/brew services 常驻"),
        .init(name: "Node 服务", category: "开发", icon: "terminal", kind: .command,
              command: "node server.js",
              checkURL: "http://localhost:{port}",
              statusCommand: "pgrep -f 'node server.js' | grep -q .",
              pidPattern: "server.js",
              description: "模板变量 port=3000；前台命令建议守护化"),

        // ── 应用 ──
        .init(name: "Safari", category: "应用", icon: "safari", kind: .app,
              appPath: "/Applications/Safari.app",
              description: "打开 Safari"),
        .init(name: "Chrome", category: "应用", icon: "globe", kind: .app,
              appPath: "/Applications/Google Chrome.app",
              description: "打开 Chrome"),
        .init(name: "终端", category: "应用", icon: "terminal", kind: .app,
              appPath: "/System/Applications/Utilities/Terminal.app",
              description: "打开终端"),
        .init(name: "VS Code", category: "应用", icon: "chevron.left.forwardslash.chevron.right", kind: .app,
              appPath: "/Applications/Visual Studio Code.app",
              description: "打开 VS Code"),

        // ── 网页 ──
        .init(name: "本地服务地址", category: "网页", icon: "link", kind: .url,
              url: "http://localhost:{port}",
              checkURL: "http://localhost:{port}",
              description: "模板变量 port=3000，打开任意本地端口"),
        .init(name: "Docker 管理台", category: "网页", icon: "gauge", kind: .url,
              url: "http://localhost:8080",
              checkURL: "http://localhost:8080",
              description: "Portainer / 其他管理台，可改端口")
    ]

    static var categories: [String] {
        var seen = Set<String>()
        return all.map(\.category).filter { seen.insert($0).inserted }.sorted()
    }

    static func templates(in category: String) -> [ServiceTemplate] {
        all.filter { $0.category == category }
    }
}
