# If you are uploading file in params, multipart will used as content-type automatically

HTTParty.post(
  'http://localhost:3000/user',
  body: {
    name: 'Foo Bar',
    email: 'example@email.com',
    avatar: File.open('/full/path/to/avatar.jpg')
  }
)


# However, you can force it yourself

HTTParty.post(
  'http://localhost:3000/user',
  multipart: true,
  body: {
    name: 'Foo Bar',
    email: 'example@email.com'
  }
)


# For large file uploads, use stream_body: true to reduce memory usage.
# Instead of loading the entire file into memory, HTTParty will stream it in chunks.
# Note: Some servers may not handle streaming uploads correctly.

HTTParty.post(
  'http://localhost:3000/upload',
  body: {
    document: File.open('/full/path/to/large_file.zip')
  },
  stream_body: true
)
