class WaImagesSweeper < ActionController::Caching::Sweeper
  observe WaImage

  def after_save(image)
    expire_cache_for(image)
  end

  def after_destroy(image)
    expire_cache_for(image)
  end

  private

  def expire_cache_for(image)
    for format in ['jpg', 'png'] do
      expire_page(:controller => 'wa_images', :action => 'show', :id => image, :name => image.name, :format => format)
    end
    expire_page(:controller => 'wa_images', :action => 'show_in_window', :id => image, :format => 'jpg')
    expire_page(:controller => 'wa_images', :action => 'thumb', :id => image, :format => 'jpg')
  end

end
