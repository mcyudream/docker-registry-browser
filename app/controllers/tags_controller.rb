require "ostruct"

class TagsController < ApplicationController
  before_action :find_tag

  def show
  end

  def destroy
    reject_destroy unless Rails.configuration.x.delete_enabled

    if @tag.delete
      redirect_with_flash :notice, "镜像标签 #{@tag.name} 已删除。"
    else
      redirect_with_flash :error, "镜像标签 #{@tag.name} 删除失败。"
    end
  rescue Faraday::ClientError => e
    case e.response[:status]
    when 401
      client_error(e)
      retry
    when 405
      render :destroy_blocked
    else
      raise
    end
  end

  private

  def find_tag
    @repository = Repository.find params[:repo]
    @tag        = Tag.find(repository: @repository, name: params[:tag])
  end

  def redirect_with_flash(type, message)
    redirect_to repository_path(@repository.name), flash: { type => message }
  end

  def reject_destroy
    raise "Tag deletion feature is not enabled.\nPlease set `ENABLE_DELETE_IMAGES=true` to enable it."
  end
end
