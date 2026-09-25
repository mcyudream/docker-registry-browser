class Collection
  include ActiveModel::Model
  include Enumerable

  attr_accessor :entries, :more, :next_query

  delegate :each, to: :entries

  def last
    entries.last
  end

  def more?
    more
  end

  def next_query
    @next_query || {}
  end
end
