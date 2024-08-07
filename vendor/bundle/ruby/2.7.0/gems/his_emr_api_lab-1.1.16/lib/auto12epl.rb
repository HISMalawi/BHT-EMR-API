#!/usr/bin/ruby
# Jeremy Espino MD MS
# 28-JAN-2016


class Float
  # function to round down a float to an integer value
  def round_down n=0
    n < 1 ? self.to_i.to_f : (self - 0.5 / 10**n).round(n)
  end
end

# Generates EPL code that conforms to the Auto12-A standard for specimen labeling
class Auto12Epl

  attr_accessor :element_font
  attr_accessor :barcode_human_font

  DPI = 203
  LABEL_WIDTH_IN = 2.0
  LABEL_HEIGHT_IN = 0.5

  # font constants
  FONT_X_DOTS = [8, 10, 12, 14, 32]
  FONT_Y_DOTS = [12, 16, 20, 24, 24]
  FONT_PAD_DOTS = 2

  # element heights
  HEIGHT_MARGIN = 0.031
  HEIGHT_ELEMENT = 0.1
  HEIGHT_ELEMENT_SPACE = 0.01
  HEIGHT_PID = 0.1
  HEIGHT_BARCODE = 0.200
  HEIGHT_BARCODE_HUMAN = 0.050

  # element widths
  WIDTH_ELEMENT = 1.94
  WIDTH_BARCODE = 1.395
  WIDTH_BARCODE_HUMAN = 1.688

  # margins
  L_MARGIN = 0.031
  L_MARGIN_BARCODE = 0.25

  # stat locations
  L_MARGIN_BARCODE_W_STAT = 0.200
  L_MARGIN_W_STAT = 0.150
  STAT_WIDTH_ELEMENT = 1.78
  STAT_WIDTH_BARCODE = 1.150
  STAT_WIDTH_BARCODE_HUMAN = 1.400

  # constants for generated EPL code
  BARCODE_TYPE = '1A'
  BARCODE_NARROW_WIDTH = '2'
  BARCODE_WIDE_WIDTH = '2'
  BARCODE_ROTATION = '0'
  BARCODE_IS_HUMAN_READABLE = 'N'
  ASCII_HORZ_MULT = 1
  ASCII_VERT_MULT = 1


  def initialize(element_font = 1, barcode_human_font = 1)
    @element_font = element_font
    @barcode_human_font = barcode_human_font
  end

  # Calculate the number of characters that will fit in a given length
  def max_characters(font, length)

    dots_per_char = FONT_X_DOTS.at(font-1) + FONT_PAD_DOTS

    num_char = ( (length * DPI)  / dots_per_char).round_down

    num_char.to_int
  end

  # Use basic truncation rule to truncate the name element i.e., if > maxCharacters cutoff and trail with +
  def truncate_name(last_name, first_name, middle_initial, is_stat)
    if is_stat
      name_max_characters = max_characters(@element_font, STAT_WIDTH_ELEMENT)
    else
      name_max_characters = max_characters(@element_font, WIDTH_ELEMENT)
    end

    if concatName(last_name, first_name, middle_initial).length > name_max_characters
      # truncate last?
      if last_name.length > 12
        last_name = last_name[0..11] + '+'
      end

      # truncate first?
      if concatName(last_name, first_name, middle_initial).length  > name_max_characters && first_name.length > 7
        first_name = first_name[0..7] + '+'
      end
    end

    concatName(last_name, first_name, middle_initial)

  end

  def concatName(last_name, first_name, middle_initial)
    last_name + ', ' + first_name + (middle_initial == nil ? '' : ' ' + middle_initial)
  end

  # The main function to generate the EPL
  def generate_epl(last_name, first_name, middle_initial, pid, dob, age, gender, col_date_time, col_name, tests, stat, acc_num, schema_track)

    # format text and set margin
    if stat == nil
      name_text = truncate_name(last_name, first_name, middle_initial, false)
      pid_dob_age_gender_text = full_justify(pid, dob + ' ' + age + ' ' + gender, @element_font, WIDTH_ELEMENT)
      l_margin = L_MARGIN
      l_margin_barcode = L_MARGIN_BARCODE
    else
      name_text = truncate_name(last_name, first_name, middle_initial, true)
      pid_dob_age_gender_text = full_justify(pid, dob + ' ' + age + ' ' + gender, @element_font, STAT_WIDTH_ELEMENT)
      stat_element_text = pad_stat_w_space(stat)
      l_margin = L_MARGIN_W_STAT
      l_margin_barcode = L_MARGIN_BARCODE_W_STAT
    end
    barcode_human_text = "#{acc_num} * #{schema_track.gsub(/\-/i, '')}"
    collector_element_text = "Col: #{col_date_time} #{col_name}"
    tests_element_text = tests

    # generate EPL statements
    name_element = generate_ascii_element(to_dots(l_margin), to_dots(HEIGHT_MARGIN), 0, @element_font, false, name_text)
    pid_dob_age_gender_element = generate_ascii_element(to_dots(l_margin), to_dots(HEIGHT_MARGIN + HEIGHT_ELEMENT + HEIGHT_ELEMENT_SPACE), 0, @element_font, false, pid_dob_age_gender_text)
    barcode_human_element = generate_ascii_element(to_dots(l_margin_barcode), to_dots(HEIGHT_MARGIN + HEIGHT_ELEMENT + HEIGHT_ELEMENT_SPACE + HEIGHT_ELEMENT + HEIGHT_ELEMENT_SPACE + HEIGHT_BARCODE), 0, @barcode_human_font, false, barcode_human_text)
    collector_element = generate_ascii_element(to_dots(l_margin), to_dots(HEIGHT_MARGIN + HEIGHT_ELEMENT + HEIGHT_ELEMENT_SPACE + HEIGHT_ELEMENT + HEIGHT_ELEMENT_SPACE + HEIGHT_BARCODE + HEIGHT_BARCODE_HUMAN + HEIGHT_ELEMENT_SPACE), 0, @element_font, false, collector_element_text)
    tests_element = generate_ascii_element(to_dots(l_margin), to_dots(HEIGHT_MARGIN + HEIGHT_ELEMENT + HEIGHT_ELEMENT_SPACE + HEIGHT_ELEMENT + HEIGHT_ELEMENT_SPACE + HEIGHT_BARCODE + HEIGHT_BARCODE_HUMAN + HEIGHT_ELEMENT_SPACE + HEIGHT_ELEMENT + HEIGHT_ELEMENT_SPACE), 0, @element_font, false, tests_element_text)
    barcode_element = generate_barcode_element(to_dots(l_margin_barcode), to_dots(HEIGHT_MARGIN + HEIGHT_ELEMENT + HEIGHT_ELEMENT_SPACE + HEIGHT_ELEMENT + HEIGHT_ELEMENT_SPACE), to_dots(HEIGHT_BARCODE)-4, schema_track)
    stat_element = generate_ascii_element(to_dots(L_MARGIN)+FONT_Y_DOTS.at(@element_font - 1)+FONT_PAD_DOTS, to_dots(HEIGHT_MARGIN), 1, @element_font, true, stat_element_text)

    # combine EPL statements
    if stat == nil
      "\nN\nR216,0\nZT\nS1\n#{name_element}\n#{pid_dob_age_gender_element}\n#{barcode_element}\n#{barcode_human_element}\n#{collector_element}\n#{tests_element}\nP3\n"
    else
      "\nN\nR216,0\nZT\nS1\n#{name_element}\n#{pid_dob_age_gender_element}\n#{barcode_element}\n#{barcode_human_element}\n#{collector_element}\n#{tests_element}\n#{stat_element}\nP3\n"
    end

  end

  # Add spaces before and after the stat text so that black bars appear across the left edge of label
  def pad_stat_w_space(stat)
    num_char = max_characters(@element_font, LABEL_HEIGHT_IN)
    spaces_needed = (num_char - stat.length) / 1
    space = ''
    spaces_needed.times do
      space = space + ' '
    end
    space + stat + space
  end

  # Add spaces between the NPID and the dob/age/gender so that line is fully justified
  def full_justify(pid, dag, font, length)
    max_char = max_characters(font, length)
    spaces_needed = max_char - pid.length - dag.length
    space = ''
    spaces_needed.times do
      space = space + ' '
    end
    pid + space + dag
  end

  # convert inches to number of dots using DPI
  def to_dots(inches)
    (inches * DPI).round
  end

  # generate ascii EPL
  def generate_ascii_element(x, y, rotation, font, is_reverse, text)
    "A#{x.to_s},#{y.to_s},#{rotation.to_s},#{font.to_s},#{ASCII_HORZ_MULT},#{ASCII_VERT_MULT},#{is_reverse ? 'R' : 'N'},\"#{text}\""
  end

  # generate barcode EPL
  def generate_barcode_element(x, y, height, schema_track)
    schema_track = schema_track.gsub("-", "").strip
    "B#{x.to_s},#{y.to_s},#{BARCODE_ROTATION},#{BARCODE_TYPE},#{BARCODE_NARROW_WIDTH},#{BARCODE_WIDE_WIDTH},#{height.to_s},#{BARCODE_IS_HUMAN_READABLE},\"#{schema_track}\""
  end

end

if __FILE__ == $0

  auto = Auto12Epl.new

  puts auto.generate_epl("Banda", "Mary", "U", "Q23-HGF", "12-SEP-1997", "19y", "F", "01-JAN-2016 14:21", "byGD", "CHEM7,Ca,Mg", nil, "KCH-16-00001234", "1600001234")
  puts "\n"
  puts auto.generate_epl("Banda", "Mary", "U", "Q23-HGF", "12-SEP-1997", "19y", "F", "01-JAN-2016 14:21", "byGD", "CHEM7,Ca,Mg", "STAT CHEM", "KCH-16-00001234", "1600001234")
  puts "\n"
  puts auto.generate_epl("Bandajustrightlas", "Mary", "U", "Q23-HGF", "12-SEP-1997", "19y", "F", "01-JAN-2016 14:21", "byGD", "CHEM7,Ca,Mg", "STAT CHEM", "KCH-16-00001234", "1600001234")
  puts "\n"
  puts auto.generate_epl("Bandasuperlonglastnamethatwonfit", "Marysuperlonglastnamethatwonfit", "U", "Q23-HGF", "12-SEP-1997", "19y", "F", "01-JAN-2016 14:21", "byGD", "CHEM7,Ca,Mg", "STAT CHEM", "KCH-16-00001234", "1600001234")
  puts "\n"
  puts auto.generate_epl("Bandasuperlonglastnamethatwonfit", "Mary", "U", "Q23-HGF", "12-SEP-1997", "19y", "F", "01-JAN-2016 14:21", "byGD", "CHEM7,Ca,Mg", "STAT CHEM", "KCH-16-00001234", "1600001234")
  puts "\n"
  puts auto.generate_epl("Banda", "Marysuperlonglastnamethatwonfit", "U", "Q23-HGF", "12-SEP-1997", "19y", "F", "01-JAN-2016 14:21", "byGD", "CHEM7,Ca,Mg", "STAT CHEM", "KCH-16-00001234", "1600001234")



end
