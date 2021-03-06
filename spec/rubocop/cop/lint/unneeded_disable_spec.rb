# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Lint::UnneededDisable do
  describe '.check' do
    let(:cop) do
      cop = described_class.new
      cop.instance_variable_get(:@options)[:auto_correct] = true
      cop.processed_source = processed_source
      cop
    end
    let(:processed_source) do
      RuboCop::ProcessedSource.new(source, ruby_version)
    end
    let(:comments) { processed_source.comments }
    let(:corrected_source) do
      RuboCop::Cop::Corrector
        .new(processed_source.buffer, cop.corrections)
        .rewrite
    end

    before do
      cop.check(offenses, cop_disabled_line_ranges, comments)
    end

    context 'when there are no disabled lines' do
      let(:offenses) { [] }
      let(:cop_disabled_line_ranges) { {} }
      let(:source) { '' }

      it 'returns an empty array' do
        expect(cop.offenses).to eq([])
      end
    end

    context 'when there are disabled lines' do
      context 'and there are no offenses' do
        let(:offenses) { [] }

        context 'and a comment disables' do
          context 'one cop' do
            let(:source) { "# rubocop:disable Metrics/MethodLength\n" }
            let(:cop_disabled_line_ranges) do
              { 'Metrics/MethodLength' => [1..Float::INFINITY] }
            end

            it 'returns an offense' do
              expect(cop.messages)
                .to eq(['Unnecessary disabling of `Metrics/MethodLength`.'])
              expect(cop.highlights)
                .to eq(['# rubocop:disable Metrics/MethodLength'])
            end

            it 'gives the right cop name' do
              expect(cop.name).to eq('Lint/UnneededDisable')
            end

            it 'autocorrects' do
              expect(corrected_source).to eq('')
            end
          end

          context 'an unknown cop' do
            let(:source) { '# rubocop:disable UnknownCop' }
            let(:cop_disabled_line_ranges) do
              { 'UnknownCop' => [1..Float::INFINITY] }
            end

            it 'returns an offense' do
              expect(cop.messages)
                .to eq(['Unnecessary disabling of `UnknownCop` (unknown cop).'])
              expect(cop.highlights)
                .to eq(['# rubocop:disable UnknownCop'])
            end
          end

          context 'itself' do
            let(:source) { '# rubocop:disable Lint/UnneededDisable' }
            let(:cop_disabled_line_ranges) do
              { 'Lint/UnneededDisable' => [1..Float::INFINITY] }
            end

            it 'does not return an offense' do
              expect(cop.offenses.empty?).to be(true)
            end
          end

          context 'itself and another cop' do
            context 'disabled on the same range' do
              let(:source) do
                '# rubocop:disable Lint/UnneededDisable, Metrics/ClassLength'
              end

              let(:cop_disabled_line_ranges) do
                { 'Lint/UnneededDisable' => [1..Float::INFINITY],
                  'Metrics/ClassLength' => [1..Float::INFINITY] }
              end

              it 'does not return an offense' do
                expect(cop.offenses.empty?).to be(true)
              end
            end

            context 'disabled on different ranges' do
              let(:source) do
                ['# rubocop:disable Lint/UnneededDisable',
                 '# rubocop:disable Metrics/ClassLength'].join("\n")
              end

              let(:cop_disabled_line_ranges) do
                { 'Lint/UnneededDisable' => [1..Float::INFINITY],
                  'Metrics/ClassLength' => [2..Float::INFINITY] }
              end

              it 'does not return an offense' do
                expect(cop.offenses.empty?).to be(true)
              end
            end

            context 'and the other cop is disabled a second time' do
              let(:source) do
                ['# rubocop:disable Lint/UnneededDisable',
                 '# rubocop:disable Metrics/ClassLength',
                 '# rubocop:disable Metrics/ClassLength'].join("\n")
              end

              let(:cop_disabled_line_ranges) do
                { 'Lint/UnneededDisable' => [1..Float::INFINITY],
                  'Metrics/ClassLength' => [(2..3), (3..Float::INFINITY)] }
              end

              it 'does not return an offense' do
                expect(cop.offenses.empty?).to be(true)
              end
            end
          end

          context 'multiple cops' do
            let(:source) do
              '# rubocop:disable Metrics/MethodLength, Metrics/ClassLength'
            end
            let(:cop_disabled_line_ranges) do
              { 'Metrics/ClassLength' => [1..Float::INFINITY],
                'Metrics/MethodLength' => [1..Float::INFINITY] }
            end

            it 'returns an offense' do
              expect(cop.messages)
                .to eq(['Unnecessary disabling of `Metrics/ClassLength`, ' \
                        '`Metrics/MethodLength`.'])
            end
          end

          context 'multiple cops, and one of them has offenses' do
            let(:source) do
              '# rubocop:disable Metrics/MethodLength, Metrics/ClassLength, ' \
              'Lint/Debugger, Lint/AmbiguousOperator'
            end
            let(:cop_disabled_line_ranges) do
              { 'Metrics/ClassLength' => [1..Float::INFINITY],
                'Metrics/MethodLength' => [1..Float::INFINITY],
                'Lint/Debugger' => [1..Float::INFINITY],
                'Lint/AmbiguousOperator' => [1..Float::INFINITY] }
            end
            let(:offenses) do
              [
                RuboCop::Cop::Offense.new(:convention,
                                          OpenStruct.new(line: 7, column: 0),
                                          'Class has too many lines.',
                                          'Metrics/ClassLength')
              ]
            end

            it 'returns an offense' do
              expect(cop.messages)
                .to eq(['Unnecessary disabling of `Metrics/MethodLength`.',
                        'Unnecessary disabling of `Lint/Debugger`.',
                        'Unnecessary disabling of `Lint/AmbiguousOperator`.'])
              expect(cop.highlights).to eq(['Metrics/MethodLength',
                                            'Lint/Debugger',
                                            'Lint/AmbiguousOperator'])
            end

            it 'autocorrects' do
              expect(corrected_source).to eq(
                '# rubocop:disable Metrics/ClassLength'
              )
            end
          end

          context 'multiple cops, and the leftmost one has no offenses' do
            let(:source) do
              '# rubocop:disable Metrics/ClassLength, Metrics/MethodLength'
            end
            let(:cop_disabled_line_ranges) do
              { 'Metrics/ClassLength' => [1..Float::INFINITY],
                'Metrics/MethodLength' => [1..Float::INFINITY] }
            end
            let(:offenses) do
              [
                RuboCop::Cop::Offense.new(:convention,
                                          OpenStruct.new(line: 7, column: 0),
                                          'Method has too many lines.',
                                          'Metrics/MethodLength')
              ]
            end

            it 'returns an offense' do
              expect(cop.messages)
                .to eq(['Unnecessary disabling of `Metrics/ClassLength`.'])
              expect(cop.highlights).to eq(['Metrics/ClassLength'])
            end

            it 'autocorrects' do
              expect(corrected_source).to eq(
                '# rubocop:disable Metrics/MethodLength'
              )
            end
          end

          context 'multiple cops, with abbreviated names' do
            context 'one of them has offenses' do
              let(:source) do
                '# rubocop:disable MethodLength, ClassLength, Debugger'
              end
              let(:cop_disabled_line_ranges) do
                { 'Metrics/ClassLength' => [1..Float::INFINITY],
                  'Metrics/MethodLength' => [1..Float::INFINITY],
                  'Lint/Debugger' => [1..Float::INFINITY] }
              end
              let(:offenses) do
                [
                  RuboCop::Cop::Offense.new(:convention,
                                            OpenStruct.new(line: 7, column: 0),
                                            'Method has too many lines.',
                                            'Metrics/MethodLength')
                ]
              end

              it 'returns an offense' do
                expect(cop.messages)
                  .to eq(['Unnecessary disabling of `Metrics/ClassLength`.',
                          'Unnecessary disabling of `Lint/Debugger`.'])
                expect(cop.highlights).to eq(%w[ClassLength Debugger])
              end
            end
          end

          context 'comment is not at the beginning of the file' do
            context 'and not all cops have offenses' do
              let(:source) do
                ['puts 1',
                 '# rubocop:disable MethodLength, ClassLength'].join("\n")
              end
              let(:cop_disabled_line_ranges) do
                { 'Metrics/ClassLength' => [2..Float::INFINITY],
                  'Metrics/MethodLength' => [2..Float::INFINITY] }
              end
              let(:offenses) do
                [
                  RuboCop::Cop::Offense.new(:convention,
                                            OpenStruct.new(line: 7, column: 0),
                                            'Method has too many lines.',
                                            'Metrics/MethodLength')
                ]
              end

              it 'registers an offense' do
                expect(cop.messages).to eq(
                  ['Unnecessary disabling of `Metrics/ClassLength`.']
                )
                expect(cop.highlights).to eq(['ClassLength'])
              end
            end
          end

          context 'misspelled cops' do
            let(:source) do
              '# rubocop:disable Metrics/MethodLenght, KlassLength'
            end
            let(:cop_disabled_line_ranges) do
              { 'KlassLength' => [1..Float::INFINITY],
                'Metrics/MethodLenght' => [1..Float::INFINITY] }
            end

            it 'returns an offense' do
              expect(cop.messages)
                .to eq(['Unnecessary disabling of `KlassLength` (unknown ' \
                        'cop), `Metrics/MethodLenght` (did you mean ' \
                        '`Metrics/MethodLength`?).'])
            end
          end

          context 'all cops' do
            let(:source) { '# rubocop : disable all' }
            let(:cop_disabled_line_ranges) do
              {
                'Metrics/MethodLength' => [1..Float::INFINITY],
                'Metrics/ClassLength' => [1..Float::INFINITY],
                # etc... (no need to include all cops here)
              }
            end

            it 'returns an offense' do
              expect(cop.messages).to eq(['Unnecessary disabling of all cops.'])
              expect(cop.highlights).to eq([source])
            end
          end

          context 'itself and all cops' do
            context 'disabled on different ranges' do
              let(:source) do
                ['# rubocop:disable Lint/UnneededDisable',
                 '# rubocop:disable all'].join("\n")
              end

              let(:cop_disabled_line_ranges) do
                { 'Lint/UnneededDisable' => [1..Float::INFINITY],
                  'all' => [2..Float::INFINITY] }
              end

              it 'does not return an offense' do
                expect(cop.offenses.empty?).to be(true)
              end
            end
          end
        end
      end

      context 'and there are two offenses' do
        let(:message) do
          'Replace class var @@class_var with a class instance var.'
        end
        let(:cop_name) { 'Style/ClassVars' }
        let(:offenses) do
          offense_lines.map do |line|
            RuboCop::Cop::Offense.new(:convention,
                                      OpenStruct.new(line: line, column: 3),
                                      message,
                                      cop_name)
          end
        end

        context 'and a comment disables' do
          context 'one cop twice' do
            let(:source) do
              ['class One',
               '  # rubocop:disable Style/ClassVars',
               '  @@class_var = 1',
               'end',
               '',
               'class Two',
               '  # rubocop:disable Style/ClassVars',
               '  @@class_var = 2',
               'end'].join("\n")
            end
            let(:offense_lines) { [3, 8] }
            let(:cop_disabled_line_ranges) do
              { 'Style/ClassVars' => [2..7, 7..9] }
            end

            it 'returns an offense' do
              expect(cop.messages)
                .to eq(['Unnecessary disabling of `Style/ClassVars`.'])
              expect(cop.highlights)
                .to eq(['# rubocop:disable Style/ClassVars'])
            end
          end

          context 'one cop and then all cops' do
            let(:source) do
              ['class One',
               '  # rubocop:disable Style/ClassVars',
               '  # rubocop:disable all',
               '  @@class_var = 1',
               'end'].join("\n")
            end
            let(:offense_lines) { [4] }
            let(:cop_disabled_line_ranges) do
              { 'Style/ClassVars' => [2..3, 3..Float::INFINITY] }
            end

            it 'returns an offense' do
              expect(cop.messages)
                .to eq(['Unnecessary disabling of `Style/ClassVars`.'])
              expect(cop.highlights)
                .to eq(['# rubocop:disable Style/ClassVars'])
            end
          end
        end
      end

      context 'and there is an offense' do
        let(:offenses) do
          [
            RuboCop::Cop::Offense.new(:convention,
                                      OpenStruct.new(line: 7, column: 0),
                                      'Tab detected.',
                                      'Layout/Tab')
          ]
        end

        context 'and a comment disables' do
          context 'that cop' do
            let(:source) { '# rubocop:disable Layout/Tab' }
            let(:cop_disabled_line_ranges) { { 'Layout/Tab' => [1..100] } }

            it 'returns an empty array' do
              expect(cop.offenses.empty?).to be(true)
            end
          end

          context 'that cop but on other lines' do
            let(:source) { ("\n" * 9) << '# rubocop:disable Layout/Tab' }
            let(:cop_disabled_line_ranges) { { 'Layout/Tab' => [10..12] } }

            it 'returns an offense' do
              expect(cop.messages)
                .to eq(['Unnecessary disabling of `Layout/Tab`.'])
              expect(cop.highlights).to eq(['# rubocop:disable Layout/Tab'])
            end
          end

          context 'all cops' do
            let(:source) { '# rubocop : disable all' }
            let(:cop_disabled_line_ranges) do
              {
                'Metrics/MethodLength' => [1..Float::INFINITY],
                'Metrics/ClassLength' => [1..Float::INFINITY]
                # etc... (no need to include all cops here)
              }
            end

            it 'returns an empty array' do
              expect(cop.offenses.empty?).to be(true)
            end
          end
        end
      end
    end
  end
end
