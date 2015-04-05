require 'savon'
require 'active_merchant'

module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    module Gateways
      # This module is included in both PaypalGateway and PaypalExpressGateway
      class WebServiceAuthentication < Gateway
        self.test_url = "https://sandbox.paymentsgateway.net/WS/Client.wsdl"
        self.live_url = "https://ws.paymentsgateway.net/Service/v1/Client.wsdl"

        CARD_TYPES = {visa: "VISA", master: "MAST", american_express: "AMER", discover: "DISC", diners_club: "DINE", jcb: "JCB"}
        E_CHECK_TYPES = {checking: "CHECKING", savings: "SAVINGS"}

        def initialize(options = {})
          requires!(options, :merchant_id, :api_login_id, :secure_transaction_key)
          super
        end

        def create_client(options = {})
          client = {
            "MerchantID" =>  @options[:merchant_id],
            "FirstName" => options[:first_name],
            "LastName" => options[:last_name],
            "CompanyName" => options[:company_name],
            "Address1" => options[:address],
            "City" => options[:city],
            "State" => options[:state],
            "PhoneNumber" => options[:phoneNumber],
            "EmailAddress" => options[:email]
          }
          message = {"client" => client}
          perform_soap_request __callee__, message
        end

        def update_client(options = {})
          client = {
            "MerchantID" =>  @options[:merchant_id],
            "ClientID" => options[:client_id],
            "FirstName" => options[:first_name],
            "LastName" => options[:last_name],
            "Address1" => options[:address],
            "City" => options[:city],
            "State" => options[:state],
            "PhoneNumber" => options[:phoneNumber],
            "EmailAddress" => options[:email]
          }
          message = {"client" => client}
          perform_soap_request __callee__, message
        end

        def delete_client(options = {})
          message = { "MerchantID" =>  @options[:merchant_id], "ClientID" => options[:client_id]}
          perform_soap_request __callee__, message
        end

        def get_client(options = {})
          message = {"MerchantID" =>  @options[:merchant_id], "ClientID" => options[:client_id]}
          perform_soap_request __callee__, message
        end

        def create_payment_method(options = {})
          if options[:payment_type].to_s == 'credit_card'
            payment = add_credit_card options
          else
            payment = add_e_check options
          end
          message = {"payment" =>  payment}
          perform_soap_request __callee__, message
        end

        # update_payment_method updates payment details

        # for credit card payment, credit card number cannot be updated
        # for eCheck payment,eCheck account number and account TRN cannot be updated

        def update_payment_method(options = {})
          if options[:payment_type] == 'credit_card'
            payment = add_credit_card options
          else
            payment = add_e_check options
          end
          message = {"payment" =>  payment}
          perform_soap_request __callee__, message
        end

        def delete_payment_method(options = {})
          message = {"MerchantID" =>  @options[:merchant_id], "ClientID" => options[:client_id],  "PaymentMethodID" =>  options[:payment_method_id]}
          perform_soap_request __callee__, message
        end

        def get_payment_method(options = {})
          message = {"MerchantID" =>  @options[:merchant_id], "ClientID" => options[:client_id],  "PaymentMethodID" =>  options[:payment_method_id]}
          perform_soap_request __callee__, message
        end

        private

        def perform_soap_request(method, message)
          url = test? ? self.test_url : self.live_url
          soap_client = Savon.client(wsdl: url)

          #Ticket must come before the actual body request.
          message = {"ticket" => get_client_auth_ticket}.merge(message)

          response = soap_client.call(method) do |locals|
            locals.message(message)
          end
          response.body
        rescue Savon::SOAPFault => error
          error.to_hash
        end

        def get_client_auth_ticket
          now = time_in_ticks.to_s
          key = OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new("md5"), @options[:secure_transaction_key], @options[:api_login_id] + "|" + now)
          {
            "APILoginID" =>  @options[:api_login_id],
            "TSHash" =>  key,
            "UTCTime" => now
          }
        end

        def time_in_ticks
          ticks_since_epoch = Time.utc(0001,01,01).to_i * 10000000
          Time.now.to_i * 10000000 + Time.now.nsec / 100 - ticks_since_epoch
        end

        def add_e_check(options = {})
          payment = {
            "MerchantID" =>   @options[:merchant_id],
            "ClientID" => options[:client_id],
          }
          payment["PaymentMethodID"] = options[:payment_method_id] if options[:payment_method_id]
          payment["AcctHolderName"] = options[:acct_holder_name]
          payment["EcAccountNumber"] = options[:account_number]
          payment["EcAccountTRN"] = options[:routing_number]
          payment["EcAccountType"] = E_CHECK_TYPES[options[:account_type]]
          payment
        end

        def add_credit_card(options = {})
          payment = {
            "MerchantID" =>  @options[:merchant_id],
            "ClientID" => options[:client_id]
          }
          payment["PaymentMethodID"] = options[:payment_method_id] if options[:payment_method_id]
          payment["AcctHolderName"] = options[:acct_holder_name]
          payment["CcCardNumber"] = options[:cc_card_number] if options[:cc_card_number]
          payment["CcExpirationDate"] = options[:cc_expiration_date] if options[:cc_expiration_date]
          payment["CcCardType"] = CARD_TYPES[options[:cc_card_type]] if options[:cc_card_type]
          payment["Note"] = options[:note] if options[:note]
          payment
        end
      end
    end
  end
end
