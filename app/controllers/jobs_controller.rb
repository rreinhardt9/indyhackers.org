require "digest/md5"
class JobsController < ApplicationController
  before_filter :authenticate_by_token, :only => [:manage, :destroy]
  skip_before_filter :verify_authenticity_token, :only => :viewed

  def index
    @jobs = Job.published.order("created_at DESC").all
    respond_to do |format|
      format.html
      format.atom { render :layout => false }
      format.rss { redirect_to jobs_path(:format => :atom), :status => :moved_permanently }
    end
  end

  def show
    if resource.blank?
      redirect_to(jobs_path, :notice => "Couldn't find that job. It may have been filled. Sorry!") and return
    end
  end

  def manage
    @job = resource
  end

  def viewed
    @job = resource
    if cookies['_ih_uid'].nil?
      cookies['_ih_uid'] = Digest::MD5.hexdigest(Time.now.to_s + rand(13000).to_s)
    end
    @viewer = Viewer.find_or_create_by_client_hash(cookies['_ih_uid'])
    unless @viewer.viewed?(@job)
      @job.viewers << @viewer
      @job.views = @job.views.nil? ? 1 : @job.views + 1
      @job.save
      INSTRUMENTAL.increment(@job.slug + "_viewed")
    end
    render :text => "Success!"
  end

  def destroy
    @job = resource
    @job.destroy
    redirect_to jobs_path
  end

  private

  def authenticate_by_token
    @job = resource
    @user = User.find_by_token(params[:token]) unless params[:token].nil?
    unless @user.present? && @job.user == @user
      redirect_to jobs_url, :notice => "*gasp* You shouldn't be snooping around there! FOR SHAME!"
    end
  end

  def resource
    if params[:id].to_i == 0
      @job = Job.find_by_slug(params[:id])
    else
      @job = Job.find_by_id(params[:id])
    end
  end
end
