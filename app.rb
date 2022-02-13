require 'ovto'
require 'parser/current'
require 'corelib/string/unpack'

module Rubyle
  class App < Ovto::App
    class State < Ovto::State
      item :user_inputs, default: []
      item :current_input, default: ''
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
    end

    class Actions < Ovto::Actions
      def update_current_input(value:)
        return { current_input: value }
      end

      def submit(value:)
        return { user_inputs: [*state.user_inputs, value] }
      end
    end

    class MainComponent < Ovto::Component
      def render
        o 'div' do
          o 'ol' do
            state.user_inputs.each do |code|
              o 'li' do
                o HighlightedUserInput, code: code, result: state.result
              end
            end
          end

          o 'textarea', {
            onchange: -> (ev) { actions.update_current_input(value: ev.target.value) },
            onkeydown: -> (ev) do
              if ev.key == 'Enter' && ev.ctrlKey
                actions.submit(value: ev.target.value)
              end
            end,
            value: state.current_input,
          }
        end
      end
    end
  end

  class HighlightedUserInput < Ovto::PureComponent
    def render(code:, result:)
      result_nodes = Util.to_nodes(result)
      highlights = []

      ast = Parser::CurrentRuby.parse(code)
      Util.traverse(ast) do |node, path|
        yellow = result_nodes.any? { |r| r[0] == node }
        green = yellow && result_nodes.any? { |r| r == [node, path] }

        if yellow || green
          highlights << [node.loc, green ? :green : :yellow]

          false 
        end
      end

      o 'pre' do
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

  module Util
    # type path = Array[Symbol | Integer]
    # () -> Array[[Parser::Node, path]]
    def self.to_nodes(code)
      ast = Parser::CurrentRuby.parse(code)
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
  end
end

Rubyle::App.run(id: 'ovto')
