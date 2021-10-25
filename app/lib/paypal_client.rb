# frozen_string_literal: true

class PaypalClient
  PAYPAL_API_URI = 'api-m.paypal.com'
  PROTOCOL_PREFIX = 'https://'
  MAX_TRANSACTION_LOOKUP_PERIOD = 31.days

  def fetch_transactions(start_time:, end_time: DateTime.now)
    transactions = []
    batch_start_time = start_time
    loop do
      max_batch_end_time = batch_start_time + MAX_TRANSACTION_LOOKUP_PERIOD
      batch_end_time = max_batch_end_time >= end_time ? end_time : max_batch_end_time
      transactions += fetch_transactions_batch(start_time: batch_start_time, end_time: batch_end_time)
      break if batch_end_time == end_time

      batch_start_time = batch_end_time
    end
    transactions.uniq!
  end

  def fetch_transactions_batch(start_time: nil, end_time: nil)
    make_paginated_request!(
      method: :get,
      path: '/v1/reporting/transactions',
      params: {
        start_date: start_time,
        end_date: end_time
      },
      &:transaction_details
    )
  end

  private

  def make_paginated_request!(**kwargs)
    items = []
    page = 0
    loop do
      page += 1
      request_parameters = kwargs.deep_merge(params: { page: page })
      response = make_request!(**request_parameters)
      items += block_given? ? yield(response) : response
      break if page >= response.total_pages
    end
    items
  end

  def make_request!(method:, path:, params: nil, headers: {})
    response = RestClient::Request.new(
      method: method,
      url: "#{base_url}#{path}",
      headers: {
        accept: :json,
        'Authorization' => "Bearer #{access_token}",
        params: params,
        **headers
      }.compact
    ).execute
    RecursiveOpenStruct.new(JSON.parse(response.body), recurse_over_arrays: true)
  end

  def access_token
    @access_token || create_access_token
  end

  def refresh_access_token!
    @access_token = create_access_token
  end

  def base_url(with_credentials: false)
    "#{PROTOCOL_PREFIX}#{with_credentials ? "#{user_credentials}@" : ''}#{PAYPAL_API_URI}"
  end

  def user_credentials
    "#{secrets.fetch(:client_id)}:#{secrets.fetch(:client_secret)}"
  end

  def secrets
    Rails.application.secrets.paypal
  end

  def create_access_token
    response = RestClient.post("#{base_url(with_credentials: true)}/v1/oauth2/token",
                               { grant_type: 'client_credentials' },
                               { accept: :json })
    JSON.parse(response).fetch('access_token')
  end
end
