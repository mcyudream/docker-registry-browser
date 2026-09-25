class TagSummary
  include ActiveModel::Model
  include Comparable

  attr_accessor :name, :push_time

  def <=>(other)
    name <=> other.name
  end

  def to_s
    name
  end
end
