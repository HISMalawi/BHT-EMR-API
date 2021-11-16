class Numeric
  MultiplicationTable = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0]
  ]

  PermutationTable = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
    [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8]
  ]

  InverseTable = [0, 4, 3, 2, 1, 5, 6, 7, 8, 9]

    # generates checksum
  def check_digit
    c = 0
    inverted_array = inv_array(self.to_s.split(""))

    inverted_array.each_with_index do |a, i|
      c = MultiplicationTable[c][PermutationTable[(i + 1) % 8][a]]
    end

    return InverseTable[c]
  end

  # validates checksum
  def check_digit_validation
    c = 0
    inverted_array = inv_array(self.to_s.split(""))

    inverted_array.each_with_index do |a, i|
      c = MultiplicationTable[c][PermutationTable[(i % 8)][a]]
    end

    return (c === 0)
  end

  private
  # converts string array to Numeric array and inverts it
  def inv_array(array)
    array = array.map{|n|n.to_i}
    return array.reverse
  end


end
