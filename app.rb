require 'ovto'
require 'native'
require 'parser/current'
require 'opal/parser/patch'
require 'corelib/string/unpack'

module Rubyle
  Alert = Struct.new(:type, :message, keyword_init: true)

  class App < Ovto::App
    class State < Ovto::State
      item :user_inputs, default: []
      item :game_clear, default: false
      item :result, default: <<~RUBY
        def fibo(n)
          if n <= 2
            1
          else
            fibo(n - 1) + fibo(n - 2)
          end
        end

        fibo 10
      RUBY
      item :alert, default: nil
    end

    class Actions < Ovto::Actions
      def submit(value:)
        return { user_inputs: [*state.user_inputs, value] }
      end

      def set_alert(message:, type:)
        return { alert: Alert.new(message: message, type: type) }
      end

      def reset_alert
        return { alert: nil }
      end
    end

    class MainComponent < Ovto::Component
      def render
        o 'div' do
          o 'ol' do
            state.user_inputs.each do |code|
              o 'li.guess-item' do
                o HighlightedUserInput, code: code, result: state.result
              end
            end
          end

          o 'textarea', {
            onkeydown: -> (ev) { on_submit(ev) },
          }

          o AlertComponent if state.alert
        end
      end

      def on_submit(ev)
        return unless ev.key == 'Enter' && ev.ctrlKey

        ev.preventDefault
        code = ev.target.value
        begin
          RubyParser.parse(code)
        rescue Parser::SyntaxError => ex
          actions.set_alert(message: "SyntaxError: #{ex.message}", type: :error)
          Util.set_timeout(5000) { actions.reset_alert }
          return
        end

        actions.submit(value: code)
      end
    end
  end

  class HighlightedUserInput < Ovto::PureComponent
    def render(code:, result:)
      result_nodes = Util.to_nodes(result)
      highlights = []

      ast = RubyParser.parse(code)
      Util.traverse(ast) do |node, path|
        yellow = result_nodes.any? { |r| r[0] == node }
        green = yellow && result_nodes.any? { |r| r == [node, path] }

        if yellow || green
          highlights << [node.loc, green ? :green : :yellow]

          false 
        end
      end

      o 'pre.guess' do
        o 'code' do
          written_pos = 0
          while h = highlights.shift
            l = h[0].expression
            bp = l.begin_pos
            ep = l.end_pos

            o 'span', code[written_pos...bp] if written_pos < bp
            o "span.#{h[1]}", code[bp..ep]
            written_pos = ep
          end
          o 'span', code[written_pos..-1] if written_pos < code.size-1
        end
      end
    end
  end

  class AlertComponent < Ovto::Component
    def render
      o "div.alert-#{state.alert.type}", state.alert.message
    end
  end

  class RubyParser < Parser::CurrentRuby
    def self.default_parser
      super.tap do |p|
        p.diagnostics.consumer = nil
      end
    end
  end

  module Util
    # type path = Array[Symbol | Integer]
    # () -> Array[[Parser::Node, path]]
    def self.to_nodes(code)
      ast = RubyParser.parse(code)
      res = []
      traverse(ast) do |node, path|
        res << [node, path]
      end
      res
    end

    def self.traverse(node, path = [], &block)
      continue = yield node, path
      return if continue == false

      node.children.each.with_index do |c, idx|
        traverse(c, [*path, node.type, idx], &block) if c.is_a?(Parser::AST::Node)
      end
    end

    def self.set_timeout(msec, &block)
      %x{
        window.setTimeout(#{block.to_n}, #{msec})
      }
    end
  end
end

Rubyle::App.run(id: 'ovto')
