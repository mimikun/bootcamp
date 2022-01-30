# frozen_string_literal: true

require 'net/http'

module LinkChecker
  class Checker
    DENY_LIST = %w[
      codepen.io
      www.amazon.co.jp
    ].freeze
    attr_reader :errors

    class << self
      def valid_url?(url)
        url = URI.encode_www_form_component(url)
        URI.parse(url)
      end
    end

    def initialize(links = [])
      @links = links
      @errors = []
      @broken_links = []
    end

    def notify_broken_links
      check
      return if @broken_links.empty?

      texts = ['リンク切れがありました。']
      @broken_links.map do |link|
        texts << "- <#{link.url}|#{link.title}> in: <#{link.source_url}|#{link.source_title}>"
      end

      ChatNotifier.message(texts.join("\n"), username: 'リンクチェッカー')
    end

    def check
      locks = Queue.new
      5.times { locks.push :lock }
      @links.reject! do |link|
        url = URI.encode_www_form_component(link.url)
        uri = URI.parse(url)
        !uri || DENY_LIST.include?(uri.host)
      end

      @links.map do |link|
        Thread.new do
          lock = locks.pop
          response = Client.request(link.url)
          link.response = response
          @broken_links << link if !response || response > 403
          locks.push lock
        end
      end.each(&:join)

      @broken_links.sort { |a, b| b.source_url <=> a.source_url }
    end
  end
end
