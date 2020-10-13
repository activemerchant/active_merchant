class FileUploadServlet < WEBrick::HTTPServlet::AbstractServlet
  def do_POST req, res
    res.body = req.body
  end

  def do_GET req, res
    res.content_type = 'text/html'
    res.body = <<-BODY
<!DOCTYPE html>
<title>Fill in this form</title>
<p>You can POST anything to this endpoint, though

<form method="POST">
<textarea name="text"></textarea>
<input type="submit">
</form>
    BODY
  end
end

