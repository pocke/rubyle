
module Rubyle
  module Hint
    class State < Ovto::State
      item :symbols, default: true
      item :code_length, default: true
    end

    module Actions
      def update_hint(symbols: nil, code_length: nil)
        { hints: state.hints.merge({ symbols:, code_length: }.compact) }
      end
    end

    class Switcher < Ovto::Component
      def render
        o 'div' do
          o Checkbox, key: :symbols, label: 'Symbols:'
          o Checkbox, key: :code_length, label: 'Code Length:'
        end
      end
    end

    class Checkbox < Ovto::Component
      def render(key:, label:)
        o 'label.hint-checkbox' do
          o 'span', label
          o 'input', type: 'checkbox', onchange: -> (ev) { p 'onchange'; actions.update_hint(key => !state.hints[key]) }, checked: state.hints[key]
        end
      end
    end

    class Display < Ovto::Component
      def render
        o 'div' do
          if state.hints.symbols
            o 'div' do
              o 'span', 'Used symbols: '
              (symbols = symbols()).each.with_index do |sym, idx|
                o 'code', sym
                o 'span', ', ' unless idx == symbols.size-1
              end
            end
          end

          if state.hints.code_length
            o 'div' do
              o 'span', "Code Length: #{state.result.size} chars"
            end
          end
        end
      end

      def symbols
        ast = RubyParser.parse(state.result)
        ret = []

        Util.traverse(ast) do |node|
          ret.concat(node.children.select { |c| c.is_a?(Symbol) })
        end

        ret.sort.uniq
      end
    end
  end
end
