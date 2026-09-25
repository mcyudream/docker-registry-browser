class Repository
  include ActiveModel::Model

  attr_accessor :name, :tags, :artifact_count, :pull_count, :update_time

  def self.list(page: nil, last: nil)
    Registry.backend.list_repositories(page: page, last: last)
  end

  def self.find(name)
    Registry.backend.find_repository(name)
  end

  def namespace(root = "")
    name.split("/").size == 1 ? root : name.split("/")[0...-1].join("/")
  end

  def image
    name.split("/").last
  end
end
