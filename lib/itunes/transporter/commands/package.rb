require 'itunes/transporter/generator'

command :package do |c|
  c.syntax = 'itmsp package [options]'
  c.summary = ''
  c.description = 'Generates iTunes Metadata Store Package (.itmsp) from provided achievement, leaderboard, and/or in-app purchases provided'
  c.example 'description', 'command example'
  c.option '-i FILENAME', '--input FILENAME', String, 'YAML file containing app/team values, achievement, leaderboard, and/or in-app purchase descriptions'
  c.option '-o PATH', '--output PATH', String, 'path where the package will be written'
  c.action do |args, options|   
    input_file = options.i || options.input
    outputdir = options.o || options.output
    output = Itunes::Transporter::Generator.new(input_file: input_file).generate_metadata(outputdir)

    say_ok output[:messages].join("\n") if output[:messages].length > 0
    say_error "Errors:\n #{output[:errors].join("\n")}" if output[:errors].length > 0
  end
end
