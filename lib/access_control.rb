class AccessControl
  PAYPAL_API_URL = 'https://api-m.sandbox.paypal.com'

  def access_token
    @access_token || create_access_token
  end

  def create_access_token
    RestClient.post()
  end
end