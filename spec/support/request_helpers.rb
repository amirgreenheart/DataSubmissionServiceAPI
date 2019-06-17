module RequestHelpers
  def json
    JSON.parse(response.body)
  end

  def json_headers
    { 'Content-Type': 'application/vnd.api+json', 'Accept': 'application/vnd.api+json' }
  end

  def auth_header(user)
    { 'X-Auth-Id' => user.auth_id }
  end
end
