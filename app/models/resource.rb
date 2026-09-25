class Resource
  private

  def self.client
    Registry::V2.client
  end

  def client
    self.class.client
  end
end
