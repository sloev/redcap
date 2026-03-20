local blueprints = {
  blog = {
    name = "Simple Blog",
    description = "A basic blog with posts and a homepage list.",
    schemas = {
      {
        name = "Post",
        json_schema = [[{
  "type": "object",
  "properties": {
    "title": { "type": "string" },
    "content": { "type": "string", "format": "markdown" },
    "date": { "type": "string" },
    "image": { "type": "string" }
  },
  "required": ["title", "content"]
}]]
      }
    },
    layouts = {
      {
        path = "/",
        html = [[
<html>
<head>
    <style>body { font-family: sans-serif; max-width: 800px; margin: 0 auto; padding: 50px; line-height: 1.6; }</style>
</head>
<body>
    <h1>Welcome to My Blog</h1>
    <p>This is a portable blog powered by Redcap CMS.</p>
    <hr>
    {% for row in db:nrows("SELECT * FROM content WHERE status = 'published'") do %}
        {% local data = DecodeJson(row.data) %}
        <article>
            <h2><a href="/{{row.slug}}">{{data.title}}</a></h2>
            <p>{{data.date or 'Recently published'}}</p>
        </article>
    {% end %}
</body>
</html>]]
      },
      {
        path = "/*",
        html = [[
<html>
<head>
    <style>body { font-family: sans-serif; max-width: 800px; margin: 0 auto; padding: 50px; line-height: 1.6; } img { max-width: 100%; }</style>
</head>
<body>
    <a href="/">← Back to Home</a>
    <h1>{{data.title}}</h1>
    <div>{{renderMarkdown(data.content)}}</div>
</body>
</html>]]
      }
    }
  },
  portfolio = {
    name = "Visual Portfolio",
    description = "Showcase your work with a clean project grid.",
    schemas = {
      {
        name = "Project",
        json_schema = [[{
  "type": "object",
  "properties": {
    "title": { "type": "string" },
    "description": { "type": "string", "format": "markdown" },
    "image": { "type": "string" },
    "link": { "type": "string" }
  },
  "required": ["title"]
}]]
      }
    },
    layouts = {
      {
        path = "/",
        html = [[
<html>
<head>
    <style>
        body { font-family: sans-serif; margin: 0; padding: 50px; background: #f9f9f9; }
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 30px; }
        .card { background: white; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 10px rgba(0,0,0,0.05); }
        .card img { width: 100%; height: 200px; object-fit: cover; }
        .card-body { padding: 20px; }
    </style>
</head>
<body>
    <h1>Portfolio</h1>
    <div class="grid">
        {% for row in db:nrows("SELECT * FROM content WHERE status = 'published'") do %}
            {% local p = DecodeJson(row.data) %}
            <div class="card">
                {% if p.image then %}<img src="{{p.image}}">{% end %}
                <div class="card-body">
                    <h3>{{p.title}}</h3>
                    <p>{{p.description:sub(1, 100)}}...</p>
                </div>
            </div>
        {% end %}
    </div>
</body>
</html>]]
      }
    }
  }
}

return blueprints
