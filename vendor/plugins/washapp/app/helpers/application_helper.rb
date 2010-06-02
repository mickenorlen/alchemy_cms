# Copyright:: 2007-2010 macabi GmbH
# Author::    Thomas von Deyen
# Date::      13.01.2010
# 
# All methods (helpers) in this helper are used by washAPP to render molecules, atoms and layouts on the WaPage.
# You can call this helper the most important part of washAPP. This helper is washAPP, actually :)
#
# TODO: list all important infos here.
# 
# Most Important Infos:
# ---
#
# 1. The most important helpers for webdevelopers are the render_navigation(), render_molecules() and the render_page_layout() helpers.
# 2. The currently displayed page can be accessed with the current_page() helper. This is actually the page found via WaPage.find_by_name("some_url_name") page
# 3. All important meta data from current_page will be rendered via the render_meta_data() helper.

module ApplicationHelper

  include FastGettext::Translation

  def configuration(name)
    return WaConfigure.parameter(name)
  end

  # Did not know of the truncate helepr form rails at this time.
  # The way is to pass this to truncate....
  def shorten(text, length)
    if text.length <= length - 1
      text
    else
      text[0..length - 1] + "..."
    end
  end
  
  def render_editor(molecule)
    render_molecule(molecule, :editor)
  end

  def get_atom(molecule, position)
    return molecule.wa_atoms[position - 1]
  end

  # Renders all molecules from current_page.
  # ---
  # == Options are:
  # :only => []                 A list of molecule names to be rendered only. Very usefull if you want to render a specific molecule type in a special html part (e.g.. <div>) of your page and all other molecules in another part.
  # :except => []               A list of molecule names to be rendered. The opposite of the only option.
  # :from_page                  The WaPage.page_layout string from which the molecules are rendered from, or you even pass a WaPage object.
  # :count                      The amount of molecules to be rendered (beginns with first molecule found)
  #
  # This helper also stores all pages where molecules gets rendered on, so we can sweep them later if caching expires!
  def render_molecules(options = {})
    default_options = {
      :except => [],
      :only => [],
      :from_page => "",
      :count => nil,
      :render_format => "html"
    }
    options = default_options.merge(options)
    if options[:from_page].blank?
      page = current_page
    else
      if options[:from_page].class == WaPage
        page = options[:from_page]
      else
        page = WaPage.find_by_page_layout_and_language(options[:from_page], session[:language])
      end
    end
    if page.blank?
      logger.warn %(\n
        ++++ WARNING: WaPage is nil in render_molecules() helper ++++
        Maybe options[:from_page] references to a page that is not created yet?\n
      )
      return ""
    else
      show_non_public = configuration(:cache_wa_pages) ? false : defined?(current_user)
      all_molecules = page.find_molecules(options, show_non_public)
      molecule_string = ""
      all_molecules.each do |molecule|
        molecule_string += render_molecule(molecule, :view, options)
      end
      molecule_string
    end
  end

  # This helper renders the WaMolecule partial for either the view or the editor part.
  # Generate molecule partials with ./script/generate molecule_partials
  def render_molecule(molecule, part = :view, options = {})
    if molecule.blank?
      logger.warn %(\n
        ++++ WARNING: Molecule is nil.\n
        Usage: render_molecule(molecule, part, options = {})\n
      )
      render :partial => "wa_molecules/#{part}_not_found", :locals => {:name => 'nil'}
    else
      default_options = {
        :shorten_to => nil,
        :render_format => "html"
      }
      options = default_options.merge(options)
      molecule.store_page(current_page) if part == :view
      path1 = "#{RAILS_ROOT}/app/views/wa_molecules/"
      path2 = "#{RAILS_ROOT}/vendor/plugins/washapp/app/views/wa_molecules/"
      partial_name = "_#{molecule.name.underscore}_#{part}.html.erb"
      if File.exists?(path1 + partial_name) || File.exists?(path2 + partial_name)
        render(
          :partial => "wa_molecules/#{molecule.name.underscore}_#{part}.#{options[:render_format]}.erb",
          :locals => {
            :wa_molecule => molecule,
            :options => options
          }
        )
      else
        logger.warn %(\n
          ++++ WARNING: Molecule #{part} partial not found for #{molecule.name}.\n
          Looking for #{partial_name}, but not found
          neither in #{path1}
          nor in #{path2}
          Use ./script/generate molecule_partials to generate them.
          Maybe you still have old style partial names? (like .rhtml). Then please rename them in .html.erb!\n
        )
        render :partial => "wa_molecules/#{part}_not_found", :locals => {:name => molecule.name}
      end
    end
  end

  # DEPRICATED: It is useless to render a helper that only renders a partial.
  # Unless it is something the website producer uses. But this is not the case here.
  def render_molecule_head molecule
    render :partial => "wa_molecules/partials/wa_molecule_head", :locals => {:wa_molecule_head => molecule}
  end

  # Renders the WaAtom partial that is given (:editor, or :view).
  # You can pass several options that are used by the different atoms.
  #
  # For the view partial:
  # :image_size => "111x93"                        Used by WaAtomPicture to render the image via RMagick to that size.
  # :css_class => ""                               This css class gets attached to the atom view.
  # :date_format => "Am %d. %m. %Y, um %H:%Mh"     Espacially fot the WaAtomDate. See Date.strftime for date formatting.
  # :caption => true                               Pass true to enable that the WaAtomPicture.caption value gets rendered.
  # :blank_value => ""                             Pass a String that gets rendered if the atom.content is blank.
  #
  # For the editor partial:
  # :css_class => ""                               This css class gets attached to the atom editor.
  # :last_image_deletable => false                 Pass true to enable that the last image of an imagecollection (e.g. image gallery) is deletable.
  def render_atom(atom, part = :view, options = {})
    if atom.nil?
      logger.warn %(\n
        ++++ WARNING: WaAtom is nil!\n
        Usage: render_atom(atom, part, options = {})\n
      )
      return part == :view ? "" : "<p class=\"atom_editor_error\">" + _("atom_not_found") + "</p>"
    elsif atom.atom.nil?
      logger.warn %(\n
        ++++ WARNING: WaAtom.atom is nil!\n
        Please delete the molecule and create it again!
      )
      return part == :view ? "" : "<p class=\"atom_editor_error\">" + _("atom_atom_not_found") + "</p>"
    end
    defaults = {
      :for_editor => {
        :as => 'text_field',
        :css_class => 'long'
      },
      :for_view => {
        :image_size => "120x90",
        :css_class => "",
        :date_format => "%d. %m. %Y, %H:%Mh",
        :caption => true,
        :blank_value => ""
      },
      :render_format => "html"
    }
    options_for_partial = defaults[('for_' + part.to_s).to_sym].merge(options[('for_' + part.to_s).to_sym])
    options = options.merge(defaults)
    render(
      :partial => "wa_atoms/#{atom.atom.class.name.underscore}_#{part.to_s}.#{options[:render_format]}.erb",
      :locals => {
        :wa_atom => atom,
        :options => options_for_partial
      }
    )
  end

  # Renders the WaAtom editor partial from the given WaAtom.
  # For options see -> render_atom
  def render_atom_editor(atom, options = {})
    render_atom(atom, :editor, :for_editor => options)
  end

  # Renders the WaAtom view partial from the given WaAtom.
  # For options see -> render_atom
  def render_atom_view(atom, options = {})
    render_atom(atom, :view, :for_view => options)
  end

  # Renders the WaAtom editor partial from the given WaMolecule for the atom_type (e.g. WaAtomRtf).
  # For multiple atoms of same kind inside one molecue just pass a position so that will be rendered.
  # Otherwise the first atom found for this type will be rendered.
  # For options see -> render_atom
  def render_atom_editor_by_type(wa_molecule, type, position = nil, options = {})
    if wa_molecule.blank?
      logger.warn %(\n
        ++++ WARNING: WaMolecule is nil!\n
        Usage: render_atom_view(wa_molecule, position, options = {})\n
      )
      return "<p class='molecule_error'>" + _("no_molecule_given") + "</p>"
    end
    if position.nil?
      atom = wa_molecule.atom_by_type(type)
    else
      atom = wa_molecule.wa_atoms.find_by_atom_type_and_position(type, position)
    end
    render_atom(atom, :editor, :for_editor => options)
  end

  # Renders the WaAtom view partial from the given WaMolecule for the atom_type (e.g. WaAtomRtf).
  # For multiple atoms of same kind inside one molecue just pass a position so that will be rendered.
  # Otherwise the first atom found for this type will be rendered.
  # For options see -> render_atom
  def render_atom_view_by_type(wa_molecule, type, position, options = {})
    if wa_molecule.blank?
      logger.warn %(\n
        ++++ WARNING: WaMolecule is nil!\n
        Usage: render_atom_view(wa_molecule, position, options = {})\n
      )
      return ""
    end
    if position.nil?
      atom = wa_molecule.atom_by_type(type)
    else
      atom = wa_molecule.wa_atoms.find_by_atom_type_and_position(type, position)
    end
    render_atom(atom, :view, :for_view => options)
  end

  # Renders the WaAtom view partial from the given WaMolecule by position (e.g. 1).
  # For options see -> render_atom
  def render_atom_view_by_position(wa_molecule, position, options = {})
    if wa_molecule.blank?
      logger.warn %(\n
        ++++ WARNING: WaMolecule is nil!\n
        Usage: render_atom_view_by_position(wa_molecule, position, options = {})\n
      )
      return ""
    end
    atom = wa_molecule.wa_atoms.find_by_position(position)
    render_atom(atom, :view, :for_view => options)
  end

  # Renders the WaAtom editor partial from the given WaMolecule by position (e.g. 1).
  # For options see -> render_atom
  def render_atom_editor_by_position(wa_molecule, position, options = {})
    if wa_molecule.blank?
      logger.warn %(\n
        ++++ WARNING: WaMolecule is nil!\n
        Usage: render_atom_view_by_position(wa_molecule, position, options = {})\n
      )
      return ""
    end
    atom = wa_molecule.wa_atoms.find_by_position(position)
    render_atom(atom, :editor, :for_editor => options)
  end

  # Renders the WaAtom editor partial found in views/wa_atoms/ for the atom with name inside the passed WaMolecule.
  # For options see -> render_atom
  def render_atom_editor_by_name(wa_molecule, name, options = {})
    if wa_molecule.blank?
      logger.warn %(\n
        ++++ WARNING: WaMolecule is nil!\n
        Usage: render_atom_view(wa_molecule, position, options = {})\n
      )
      return "<p class='molecule_error'>" + _("no_molecule_given") + "</p>"
    end
    atom = wa_molecule.atom_by_name(name)
    render_atom(atom, :editor, :for_editor => options)
  end

  # Renders the WaAtom view partial from the passed WaMolecule for passed atom name.
  # For options see -> render_atom
  def render_atom_view_by_name(wa_molecule, name, options = {})
    if wa_molecule.blank?
      logger.warn %(\n
        ++++ WARNING: WaMolecule is nil!\n
        Usage: render_atom_view(wa_molecule, position, options = {})\n
      )
      return ""
    end
    atom = wa_molecule.atom_by_name(name)
    render_atom(atom, :view, :for_view => options)
  end

  # Returns current_page.title
  #
  # The options are:
  # :prefix => ""
  # :seperator => "|"
  #
  # == Webdevelopers:
  # Please use the render_meta_data() helper. There all important meta information gets rendered in one helper.
  # So you dont have to worry about anything.
  def render_page_title options={}
    default_options = {
      :prefix => "",
      :seperator => "|"
    }
    default_options.update(options)
    unless current_page.title.blank?
      h("#{default_options[:prefix]} #{default_options[:seperator]} #{current_page.title}")
    else
      h("")
    end
  end

  # Returns a complete html <title> tag for the <head> part of the html document.
  #
  # == Webdevelopers:
  # Please use the render_meta_data() helper. There all important meta information gets rendered in one helper.
  # So you dont have to worry about anything.
  def render_title_tag options={}
    default_options = {
      :prefix => "",
      :seperator => "|"
    }
    options = default_options.merge(options)
    title = render_page_title(options)
    %(<title>#{title}</title>)
  end

  # Renders a html <meta> tag for :name => "" and :content => ""
  #
  # == Webdevelopers:
  # Please use the render_meta_data() helper. There all important meta information gets rendered in one helper.
  # So you dont have to worry about anything.
  def render_meta_tag(options={})
    default_options = {
      :name => "",
      :default_language => "de",
      :content => ""
    }
    options = default_options.merge(options)
    lang = (current_page.language.blank? ? options[:default_language] : current_page.language)
    %(<meta name="#{options[:name]}" content="#{options[:content]}" lang="#{lang}" xml:lang="#{lang}" />)
  end

  # Renders a html <meta http-equiv="Content-Language" content="#{lang}" /> for current_page.language.
  #
  # == Webdevelopers:
  # Please use the render_meta_data() helper. There all important meta information gets rendered in one helper.
  # So you dont have to worry about anything.
  def render_meta_content_language_tag(options={})
    default_options = {
      :default_language => "de"
    }
    options = default_options.merge(options)
    lang = (current_page.language.blank? ? options[:default_language] : current_page.language)
    %(<meta http-equiv="Content-Language" content="#{lang}" />)
  end

  # = This helper takes care of all important meta tags for your current_page.
  # ---
  # The meta data is been taken from the current_page.title, current_page.meta_description, current_page.meta_keywords, current_page.updated_at and current_page.language database entries managed by the washAPP user via the washAPP cockpit.
  #
  # Assume that the user has entered following data into the washAPP cockpit of the WaPage "home" and that the user wants that the searchengine (aka. google) robot should index the page and should follow all links on this page:
  #
  # Title = Homepage
  # Description = The homepage of macabi gmbh - germany. We produced washapp and develop individual software solutions written in rubyonrails.
  # Keywords: washapp, ruby, rubyonrails, rails, software, development, html, javascript, ajax
  # 
  # Then placing render_meta_data(:title_prefix => "macabi", :title_seperator => "::") into the <head> part of the wa_pages.html.erb layout produces:
  #
  # <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  # <meta http-equiv="Content-Language" content="de" />
  # <title>macabi :: #{current_page.title}</title>
  # <meta name="description" content="The homepage of macabi gmbh - germany. We produced washapp and develop individual software solutions written in rubyonrails." />
  # <meta name="keywords" content="washapp, ruby, rubyonrails, rails, software, development, html, javascript, ajax" />
  # <meta name="generator" content="washAPP 2.2" />
  # <meta name="date" content="Tue Dec 16 10:21:26 +0100 2008" />
  # <meta name="robots" content="index, follow" />
  # 
  def render_meta_data options={}
    default_options = {
      :title_prefix => "",
      :title_seperator => "|",
      :default_lang => "de"
    }
    options = default_options.merge(options)
    #render meta description of the root page from language if the current meta description is empty
    if current_page.meta_description.blank?
      description = WaPage.language_root(session[:language]).meta_description
    else
      description = current_page.meta_description
    end
    #render meta keywords of the root page from language if the current meta keywords is empty
    if current_page.meta_keywords.blank?
      keywords = WaPage.language_root(session[:language]).meta_keywords
    else
      keywords = current_page.meta_keywords
    end
    robot = "#{current_page.robot_index? ? "" : "no"}index, #{current_page.robot_follow? ? "" : "no"}follow"
    %(
      <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
      #{render_meta_content_language_tag}
      #{render_title_tag( :prefix => options[:title_prefix], :seperator => options[:title_seperator])}
      #{render_meta_tag( :name => "description", :content => description)}
      #{render_meta_tag( :name => "keywords", :content => keywords)}
      <meta name="generator" content="washAPP #{configuration(:washapp_version)}" />
      <meta name="date" content="#{current_page.updated_at}" />
      <meta name="robots" content="#{robot}" />
    )
  end

  # Returns an array of all pages in the same branch from current. Used internally to find the active page in navigations.
  def breadcrumb current
    return [] if current.nil?
    result = Array.new
    result << current
    while current = current.parent
      result << current
    end
    return result.reverse
  end

  # Returns a html string for a linked breadcrump to current_page.
  # == Options:
  # :seperator => %(<span class="seperator">></span>)      Maybe you don't want this seperator. Pass another one.
  # :page => current_page                                  Pass a different WaPage instead of the default current_page.
  # :without => nil                                        Pass WaPage object that should not be displayed inside the breadcrumb.
  def render_breadcrumb(options={})
    default_options = {
      :seperator => %(<span class="seperator">></span>),
      :page => current_page,
      :without => nil
    }
    options = default_options.merge(options)
    bc = ""
    pages = breadcrumb(options[:page])
    pages.delete(WaPage.root)
    unless options[:without].nil?
      unless options[:without].class == Array
        pages.delete(options[:without])
      else
        pages = pages - options[:without]
      end
    end
    pages.each do |page|
      if page.name == current_page.name
        css_class = "active"
      elsif page == pages.last
        css_class = "last"
      elsif page == pages.first
        css_class = "first"
      end
      if (page == WaPage.language_root(session[:language]))
        if configuration(:redirect_index)
          url = show_page_url(:urlname => page.urlname)
        else
          url = index_url
        end
      else
        url = show_page_url(:urlname => page.urlname)
      end
      bc << link_to( h(page.name), url, :class => css_class, :title => page.title )
      unless page == pages.last
        bc << options[:seperator]
      end
    end
    bc
  end

  # returns true if page is in the active branch
  def page_active? page
    @breadcrumb ||= breadcrumb(@wa_page)
    @breadcrumb.include? page
  end

  # = This helper renders the navigation.
  #
  # It produces a html <ul><li></li></ul> structure with all necessary classes and ids so you can produce nearly every navigation the web uses today.
  # E.G. dropdown-navigations, simple mainnavigations or even complex nested ones.
  # ---
  # == En detail:
  # 
  # <ul>
  #   <li class="first" id="home"><a href="home" class="active">Homepage</a></li>
  #   <li id="contact"><a href="contact">Contact</a></li>
  #   <li class="last" id="imprint"><a href="imprint">Imprint</a></li>
  # </ul>
  #
  # As you can see: Everything you need.
  #
  # Not pleased with the way washAPP produces the navigation structure?
  # Then feel free to overwrite the partials (_navigation_renderer.html.erb and _navigation_link.html.erb) found in views/wa_pages/partials/ or pass different partials via the options :navigation_partial and :navigation_link_partial.
  #
  # == The options are:
  #
  # :submenu => false                                     Do you want a nested <ul> <li> structure for the deeper levels of your navigation, or not? Used to display the subnavigation within the mainnaviagtion. E.g. for dropdown menues.
  # :from_page => WaPage.language_root session[:language]      Do you want to render a navigation from a different page then the current_page? Then pass the WaPage object here.
  # :spacer => ""                                         Yeah even a spacer for the entries can be passed. Simple string, or even a complex html structure. E.g: "<span class='spacer'>|</spacer>". Only your imagination is the limit. And the W3C of course :)
  # :navigation_partial => "navigation_renderer"          Pass a different partial to be taken for the navigation rendering. CAUTION: Only for the advanced washAPP webdevelopers. The standard partial takes care of nearly everything. But maybe you are an adventures one ^_^
  # :navigation_link_partial => "navigation_link"         washAPP places an <a> html link in <li> tags. The tag automatically has an active css class if necessary. So styling is everything. But maybe you don't want this. So feel free to make you own partial and pass the filename here.
  # :show_nonactive => false                              Commonly washAPP only displays the submenu of the active page (if :submenu => true). If you want to display all child pages then pass true (together with :submenu => true of course). E.g. for the popular css-driven dropdownmenues these days.
  # :show_title => true                                  For our beloved SEOs :). Appends a title attribute to all links and places the page.title content into it.
  def render_navigation(options = {})
    default_options = {
      :submenu => false,
      :all_sub_menues => false,
      :from_page => root_page,
      :spacer => "",
      :navigation_partial => "wa_pages/partials/navigation_renderer",
      :navigation_link_partial => "wa_pages/partials/navigation_link",
      :show_nonactive => false,
      :restricted_only => nil,
      :show_title => true,
      :level => 1
    }
    options = default_options.merge(options)
    if options[:from_page].nil?
      logger.warn %(\n
        ++++ WARNING: options[:from_page] is nil in render_navigation()\n
      )
      return ""
    else
      conditions = {
        :parent_id => options[:from_page].id,
        :restricted => options[:restricted_only] || false,
        :visible => true
      }
      if options[:restricted_only].nil?
        conditions.delete(:restricted)
      end
      pages = WaPage.all(
        :conditions => conditions,
        :order => "lft ASC"
      )
      render :partial => options[:navigation_partial], :locals => {:options => options, :pages => pages}
    end
  end

  # = This helper renders the paginated navigation.
  #
  # :pagination => {
  #   :level_X => {
  #     :size => X,
  #     :current => params[:navigation_level_X_page]
  #   }
  # }                                                     This one is a funky complex pagination option for the navigation. I'll explain in the next episode.
  def render_paginated_navigation(options = {})
    default_options = {
      :submenu => false,
      :all_sub_menues => false,
      :from_page => root_page,
      :spacer => "",
      :pagination => {},
      :navigation_partial => "wa_pages/partials/navigation_renderer",
      :navigation_link_partial => "wa_pages/partials/navigation_link",
      :show_nonactive => false,
      :show_title => true,
      :level => 1
    }
    options = default_options.merge(options)
    if options[:from_page].nil?
      logger.warn %(\n
        ++++ WARNING: options[:from_page] is nil in render_navigation()\n
      )
      return ""
    else
      pagination_options = options[:pagination].stringify_keys["level_#{options[:from_page].depth}"]
      find_conditions = { :parent_id => options[:from_page].id, :visible => true }
      pages = WaPage.all(
        :page => pagination_options,
        :conditions => find_conditions,
        :order => "lft ASC"
      )
      render :partial => options[:navigation_partial], :locals => {:options => options, :pages => pages}
    end
  end
  
  # Renders the same html structure like the render_navigation() helper, but renders only child pages from current_page.
  # Shows the child pages of the active child page as default.
  # Take this helpr if you want to render the subnavigation independent from the mainnavigation. E.g. to place it in a different <div> on your page.
  def render_subnavigation options = {}
    default_options = {
      :submenu => true,
      :from_page => current_page,
      :spacer => "",
      :navigation_partial => "wa_pages/partials/navigation_renderer",
      :navigation_link_partial => "wa_pages/partials/navigation_link",
      :show_nonactive => false
    }
    options = default_options.merge(options)
    if options[:from_page].nil?
      logger.warn("WARNING: No page for subnavigation found!")
      return ""
    else
      if options[:from_page].language_level == 1
        pages = options[:from_page].children
      elsif options[:from_page].language_level == 2
        pages = options[:from_page].parent.children
      elsif options[:from_page].language_level == 3
        pages = options[:from_page].parent.self_and_siblings
      else
        pages = options[:from_page].self_and_siblings
      end
      pages = pages.select{ |page| page.public? && page.visible?}
      pages = pages.sort{|x, y| x.self_and_siblings.index(x) <=> y.self_and_siblings.index(y) }
      render :partial => options[:navigation_partial], :locals => {:options => options, :pages => pages}
    end
  end
  
  # Used to display the pagination links for the paginated navigation.
  def link_to_navigation_pagination name, urlname, pages, page, css_class = ""
    p = {}
    p["navigation_level_1_page"] = params[:navigation_level_1_page] unless params[:navigation_level_1_page].nil?
    p["navigation_level_2_page"] = params[:navigation_level_2_page] unless params[:navigation_level_2_page].nil?
    p["navigation_level_3_page"] = params[:navigation_level_3_page] unless params[:navigation_level_3_page].nil?
    p["navigation_level_#{pages.to_a.first.depth}_page"] = page
    link_to name, show_page_url(urlname, p), :class => (css_class unless css_class.empty?)
  end  
  
  # Returns true if the current_user (The logged-in washAPP User) has the admin role.
  def is_admin?
    return false if !current_user
    current_user.admin?
  end
  
  # This helper renders the link for a protoypejs-window overlay. We use this for our fancy modal overlay windows in the washAPP cockpit.
  def link_to_wa_window(content, url, options={}, html_options={})
    default_options = {
      :size => "100x100",
      :resizable => false,
      :modal => true
    }
    options = default_options.merge(options)
    link_to_function(
      content,
      "wa_overlay_window(
        \'#{url}\',
        \'#{options[:title]}\',
        \'#{options[:size].split('x')[0]}\',
        \'#{options[:size].split('x')[1]}\',
        \'#{options[:resizable]}\',
        \'#{options[:modal]}\',
        \'#{options[:overflow]}\'
      )",
      html_options
    )
  end
  
  # Used for rendering the folder link in WaAdmin.index sitemap.
  def render_sitemap_folder(site, image_pos, foldable = true)
    if foldable
      x_pos = (image_pos + 1 + (site.folded?(current_user.id) ? 1 : 0)) * 15
    else
      x_pos = image_pos * 15
    end
    style = "background-position: -#{x_pos}px 0;"
    line_image = %(
      <span style="#{style}" class="sitemap_line"></span>
    )
    if foldable && !site.children.empty?
      link_to_remote('',
        :url => {
          :controller => :wa_pages,
          :action => :fold,
          :id => site.id
        },
        :complete => %(
          fold_page(#{site.id});
          wa_overlay.updateHeight();
          if (wa_page_select_scrollbar) {
            wa_page_select_scrollbar.recalculateLayout();
          }
        ),
        :html => {
          :class => "sitemap_line folder_link",
          :title => "Unterseiten anzeigen/verstecken",
          :style => style,
          :id => "fold_button_#{site.id}"
        }
      )
    else
      line_image
    end
  end

  # Renders the sitemap lines for WaAdmin.index
  def render_sitemap_lines(wa_page, foldable)
    last_page = (wa_page.self_and_siblings.last == wa_page)
    lines = ""
    case wa_page.language_level

      when 1 then
        lines += render_sitemap_folder(wa_page, (last_page ? 4 : 1), foldable)
    	  return lines

      when 2 then
        # Erste Reihe leer oder Linie?
        if wa_page.parent == wa_page.parent.self_and_siblings.last
      		lines += '<span class="sitemap_line_spacer"></span>'
        else
      		lines += '<span style="background-position: 0 0;" class="sitemap_line"></span>'
      	end
      	# zweite Reihe Mittellinie oder Endlinie?
      	lines += render_sitemap_folder(wa_page, (last_page ? 4 : 1), foldable)
    	  return lines

      when 3 then
        # Erste Reihe leer oder Linie?
        if wa_page.parent.parent == wa_page.parent.parent.self_and_siblings.last
      	  lines += '<span class="sitemap_line_spacer"></span>'
        else
      		lines += '<span style="background-position: 0 0;" class="sitemap_line"></span>'
      	end
        # zweite Reihe leer, oder Linie?
        if wa_page.parent == wa_page.parent.self_and_siblings.last
          lines += '<span class="sitemap_line_spacer"></span>'
        else
          lines += '<span style="background-position: 0 0;" class="sitemap_line"></span>'
      	end
        # dritte Reihe Mittellinie, oder Endlinie?
        lines += %(<span style="background-position: -#{last_page ? 60 : 15}px 0;" class="sitemap_line"></span>)
    	  return lines

    end
  end
  
  # Renders an image_tag with .png for file.suffix.
  # The images are in vendor/plugins/washapp/assets/images/file_icons
  # Fileicons so far:
  # GIF
  # PDF
  # FLV (Flashvideo)
  # ZIP
  # SWF (Flashmovie)
  # MP3
  # Empty File
  def render_file_icon file
    if file.filename.split(".").last == "pdf"
      img_tag = "#{image_tag("file_icons/pdf.png", :plugin => :washapp)}"
    elsif file.filename.split(".").last == "flv"
      img_tag = "#{image_tag("file_icons/flv.png", :plugin => :washapp)}"
    elsif file.filename.split(".").last == "gif"
      img_tag = "#{image_tag("file_icons/gif.png", :plugin => :washapp)}"
    elsif file.filename.split(".").last == "zip"
      img_tag = "#{image_tag("file_icons/zip.png", :plugin => :washapp)}"
    elsif file.filename.split(".").last == "mp3"
      img_tag = "#{image_tag("file_icons/mp3.png", :plugin => :washapp)}"
    elsif file.filename.split(".").last == "swf"
      img_tag = "#{image_tag("file_icons/swf.png", :plugin => :washapp)}"
    elsif file.filename.split(".").last == "doc"
      img_tag = "#{image_tag("file_icons/doc.png", :plugin => :washapp)}"
    elsif file.filename.split(".").last == "jpg"
      img_tag = "#{image_tag("file_icons/jpg.png", :plugin => :washapp)}"
    else
      img_tag = "#{image_tag("file_icons/file.png", :plugin => :washapp)}"
    end
  end
  
  # Renders an image_tag from for an image in public/images folder so it can be cached.
  # *Not really working!*
  def static_image_tag image, options={}
    image_tag url_for(:controller => :wa_images, :action => :show_static, :image => image)
  end
  
  # Renders the layout from current_page.page_layout. File resists in /app/views/page_layouts/_LAYOUT-NAME.html.erb
  def render_page_layout(options={})
    default_options = {
      :render_format => "html"
    }
    options = default_options.merge(options)
    if File.exists?("#{RAILS_ROOT}/app/views/page_layouts/_#{@wa_page.page_layout.downcase}.#{options[:render_format]}.erb") || File.exists?("#{RAILS_ROOT}/vendor/plugins/washapp/app/views/page_layouts/_#{@wa_page.page_layout.downcase}.#{options[:render_format]}.erb")
      render :partial => "page_layouts/#{@wa_page.page_layout.downcase}.#{options[:render_format]}.erb"
    else
      render :partial => "page_layouts/standard"
    end
  end
  
  # returns @wa_page set in the action (e.g. WaPage.by_name)
  def current_page
    if @wa_page.nil?
      logger.warn %(\n
        ++++ WARNING: @wa_page is not set. Rendering Rootpage instead.\n
      )
      return @wa_page = root_page
    else
      @wa_page
    end
  end

  # returns the current language root
  def root_page
    @root_page ||= WaPage.language_root(session[:language])
  end
  
  # Returns true if the current_page is the root_page in the nested set of WaPages, false if not.
  def root_page?
    current_page == root_page
  end
  
  # Returns the full url containing host, wa_page and anchor for the given molecule
  def full_url_for_molecule molecule
    "http://" + request.env["HTTP_HOST"] + "/" + molecule.wa_page.urlname + "##{molecule.name}_#{molecule.id}"  
  end

  # Used for language selector in washAPP cockpit sitemap. So the user can select the language branche of the page.
  def language_codes_for_select
    configuration(:languages).collect{ |language|
      language[:language_code]
    }
  end

  # Used for translations selector in washAPP cockpit user settings.
  def translations_for_select
    configuration(:translations).collect{ |translation|
      [translation[:language], translation[:language_code]]
    }
  end

  # Used by washAPP to display a javascript driven filter for lists in the washAPP cockpit.
  def js_filter_field options = {}
    default_options = {
      :class => "thin_border js_filter_field",
      :onkeyup => "wa_filter('#wa_contact_list li')",
      :id => "search_field"
    }
    options = default_options.merge(options)
    options[:onkeyup] << ";$('search_field').value.length >= 1 ? $$('.js_filter_field_clear')[0].show() : $$('.js_filter_field_clear')[0].hide();"
    filter_field = "<div class=\"js_filter_field_box\">"
    filter_field << text_field_tag("filter", "", options)
    filter_field << link_to_function(
      "",
      "$('#{options[:id]}').value = '';#{options[:onkeyup]}",
      :class => "js_filter_field_clear",
      :style => "display:none",
      :title => _("click_to_show_all")
    )
    filter_field << ("<br /><label for=\"search_field\">" + _("search") + "</label>")
    filter_field << "</div>"
    filter_field
  end

  # This is the call for the javascript RTF Editor displayed in the editor views of the WaAtomRtf atoms.
  def wa_editor(editor_id, atom_id, div_to_insert, klass, method, lang, options)
    lang = lang || "de"
    html_string = %(
      <script type="text/javascript" charset="utf-8">
      //<![CDATA[
        wa_editor(
          "#{editor_id}",
          "wa_editor_rtfarea",
          "#{div_to_insert}",
          "#{klass}",
          "#{method}",
          "#{atom_id}",
          "#{options[:link_urls_for].to_s}"
        );
      //]]>
      </script>
      <input type="hidden" name="atoms[atom_#{atom_id}]" id="rtf_atom_#{atom_id}_content" class="rtf_atom_content" atom_id="#{atom_id}" />
    )
    render :inline => html_string
  end

  # returns all molecules that could be placed on that page because of the pages layout as array to be used in wa_select form builder
  def molecules_for_select(molecules)
    return [] if molecules.nil?
    options = molecules.collect{|p| [p["display_name"], p["name"]]}
    unless session[:clipboard].nil?
      pastable_molecule = WaMolecule.get_from_clipboard(session[:clipboard])
      if !pastable_molecule.nil?
        options << [
          _("'%{name}' from_clipboard") % {:name => "#{pastable_molecule.display_name_with_preview_text}"},
          "paste_from_clipboard"
        ]
      end
    end
    options
  end

  def delete_with_confirmation_link(link_string = "", message = "", url = "", html_options = {})
    ajax = remote_function(:url => url, :success => "confirm.close()", :method => :delete)
    link_to_function(
      link_string,
      "confirm = Dialog.confirm( '#{message}', {width:300, height: 80, okLabel: '" + _("yes") + "', cancelLabel: '" + _("no") + "', buttonClass: 'button', id: 'wa_confirm_dialog', className: 'wa_window', closable: true, title: '" + _("please_confirm") + "', draggable: true, recenterAuto: false, effectOptions: {duration: 0.2}, cancel:function(){}, ok:function(){ " + ajax + " }} );",
      html_options
    )
  end

  def wa_page_selector(wa_molecule, atom_name, options = {}, select_options = {})
    default_options = {
      :except => {
        :page_layout => [""]
      },
      :only => {
        :page_layout => [""]
      }
    }
    options = default_options.merge(options)
    atom = wa_molecule.atom_by_name(atom_name)
    if atom.nil?
      logger.warn %(\n
        ++++ WARNING: WaAtom is nil!\n
      )
      return "<p class=\"atom_editor_error\">" + _("atom_not_found") + "</p>"
    elsif atom.atom.nil?
      logger.warn %(\n
        ++++ WARNING: WaAtom.atom is nil!\n
      )
      return "<p class=\"atom_editor_error\">" + _("atom_atom_not_found") + "</p>"
    end
    pages = WaPage.find(
      :all,
      :conditions => {
        :language => session[:language],
        :page_layout => options[:only][:page_layout],
        :public => true
      }
    )
    select_tag(
      "atoms[atom_#{atom.id}][content]",
      wa_pages_for_select(pages, atom.atom.content),
      select_options
    )
  end

  # Returns all WaPages found in the database as an array for the rails select_tag helper.
  # You can pass a collection of pages to only returns these pages as array.
  # Pass an WaPage.name or WaPage.urlname as second parameter to pass as selected for the options_for_select helper.
  def wa_pages_for_select(pages = nil, selected = nil, prompt = "Bitte wählen Sie eine Seite")
    result = [[prompt, ""]]
    if pages.blank?
      pages = WaPage.find_all_by_language_and_public(session[:language], true)
    end
    pages.each do |p|
      result << [p.send(:name), p.send(:urlname)]
    end
    options_for_select(result, selected)
  end

  # Returns all public molecules found by WaMolecule.name.
  # Pass a count to return only an limited amount of molecules.
  def all_molecules_by_name(name, options = {})
    default_options = {
      :count => nil
    }
    options = default_options.merge(options)
    all_molecules = WaMolecule.find_all_by_name_and_public(name, true)
    molecules = []
    all_molecules.each_with_index do |molecule, i|
      unless options[:count].nil?
        if i < options[:count]
          molecules << molecule
        end
      else
        molecules << molecule
      end
    end
    molecules.reverse
  end

  # Returns the public molecule found by WaMolecule.name from the given public WaPage, either by WaPage.id or by WaPage.urlname
  def molecule_from_page(options = {})
    default_options = {
      :page_urlname => "",
      :page_id => nil,
      :molecule_name => ""
    }
    options = default_options.merge(options)
    if options[:page_id].blank?
      page = WaPage.find_by_urlname_and_public(options[:page_urlname], true)
    else
      page = WaPage.find_by_id_and_public(options[:page_id], true)
    end
    return "" if page.blank?
    molecule = page.wa_molecules.find_by_name_and_public(options[:molecule_name], true)
    return molecule
  end

  # This helper renderes the picture editor for the wa_molecules on the washAPP Desktop.
  # It brings full functionality for adding images to the wa_molecule, deleting images from it and sorting them via drag'n'drop.
  # Just place this helper inside your wa_molecule editor view, pass the wa_molecule as parameter and that's it.
  #
  # Options:
  # :last_image_deletable (boolean), default true. This option handels the possibility to delete the last image. Maybe your customer don't want an image in his molecule for a particular reason, then this options is the right one for you.
  # :maximum_amount_of_images (integer), default nil. This option let you handle the amount of images your customer can add to this molecule.
  def render_picture_editor(wa_molecule, options={})
    default_options = {
      :last_image_deletable => true,
      :maximum_amount_of_images => nil,
      :refresh_sortable => true
    }
    options = default_options.merge(options)
    picture_atoms = wa_molecule.all_atoms_by_type("WaAtomPicture")
    render(
      :partial => "wa_molecules/wa_picture_editor",
      :locals => {
        :picture_atoms => picture_atoms,
        :wa_molecule => wa_molecule,
        :options => options
      }
    )
  end
  
  def render_atom_selection_editor(wa_molecule, atom, select_options)
    if atom.class == String
       atom = wa_molecule.wa_atoms.find_by_name(atom)
    else
      atom = wa_molecule.wa_atoms[atom - 1]
    end
    if atom.atom.nil?
      logger.warn %(\n
        ++++ WARNING: WaMolecule is nil!\n
        Usage: render_atom_editor_by_position(wa_molecule, position, options = {})\n
      )
      return _("atom_atom_not_found")
    end
    select_options = options_for_select(select_options, atom.atom.content)
    select_tag(
      "atoms[atom_#{atom.id}]",
      select_options
    )
  end
  
  def picture_editor_sortable(wa_molecule_id)
    sortable_element(
      "molecule_#{wa_molecule_id}_atoms",
      :scroll => 'window',
      :tag => 'div',
      :only => 'dragable_picture',
      :handle => 'picture_handle',
      :constraint => '',
      :overlap => 'horizontal',
      :url => {
        :controller => 'wa_atoms',
        :action => "order",
        :wa_molecule_id => wa_molecule_id
      }
    )
  end
  
  def current_language
    session[:language]
  end
  
  # TOOD: include these via asset_packer yml file
  def stylesheets_from_plugins
    Dir.glob("vendor/plugins/*/assets/stylesheets/*.css").select{|s| !s.include? "vendor/plugins/washapp"}.inject("") do |acc, s|
      filename = File.basename(s)
      plugin = s.split("/")[2]
      acc << stylesheet_link_tag(filename, :plugin => plugin)
    end
  end

  # TOOD: include these via asset_packer yml file  
  def javascripts_from_plugins
    Dir.glob("vendor/plugins/*/assets/javascripts/*.js").select{|s| !s.include? "vendor/plugins/washapp"}.inject("") do |acc, s|
      filename = File.basename(s)
      plugin = s.split("/")[2]
      acc << javascript_include_tag(filename, :plugin => plugin)
    end
  end

  def washapp_main_navigation
    navigation_entries = wa_plugins.collect{ |p| p["navigation"] }
    render :partial => 'layouts/partials/wa_mainnavigation_entry', :collection => navigation_entries.flatten
  end

  #:nodoc:
  def render_washapp_subnavigation(entries)
    render :partial => "layouts/partials/wa_subnavigation", :locals => {:entries => entries}
  end

  def washapp_subnavigation
    plugin = wa_plugin(:controller => params[:controller], :action => params[:action])
    unless plugin.nil?
      entries = plugin["navigation"]['sub_navigation']
      render_washapp_subnavigation(entries) unless entries.nil?
    else
      ""
    end
  end
  
  #true if the current controller/action pair wants to display content other than the default.
  def frame_requested?
    preview_frame = {}
    plugin = wa_plugins.detect do |p|
      unless p["preview_frame"].nil?
        if p['preview_frame'].is_a?(Array)
          preview_frame = p['preview_frame'].detect(){ |f| f["controller"] == params[:controller] && f["action"] == params[:action] }
        else
          if p["preview_frame"]["controller"] == params[:controller] && p["preview_frame"]["action"] == params[:action]
            preview_frame = p["preview_frame"]
          end
        end
      end
    end
    return false if plugin.blank?
    preview_frame
  end
  
  def washapp_mainnavi_active?(mainnav)
    subnavi = mainnav["sub_navigation"]
    nested = mainnav["nested"]
    if !subnavi.blank?
      (!subnavi.detect{ |subnav| subnav["controller"] == params[:controller] && subnav["action"] == params[:action] }.blank?) ||
      (!nested.nil? && !nested.detect{ |n| n["controller"] == params[:controller] && n["action"] == params[:action] }.blank?)
    else
      mainnav["controller"] == params[:controller] && mainnav["action"] == params["action"]
    end
  end
  
  #generates the url for the preview frame.
  #target_url must contain target_controller and target_action or be blank
  def generate_preview_url target_url
    if target_url.blank?
      preview_url = url_for(:controller => "/wa_preview_content", :action => "show_content", :for => params)
    else
      preview_url = url_for(:controller => ('/' + target_url["target_controller"]), :action => target_url["target_action"], :id => params[:id])
    end
  end
  
  # Returns a string for the id attribute of a html element for the given molecule
  def molecule_dom_id(wa_molecule)
    return "" if wa_molecule.nil?
    "#{wa_molecule.name}_#{wa_molecule.id}"
  end
  
  # Returns a string for the id attribute of a html element for the given atom
  def atom_dom_id(wa_atom)
    return "" if wa_atom.nil?
    if wa_atom.class == String
      a = WaAtom.find_by_name(wa_atom)
      return "" if a.nil?
    else
      a = wa_atom
    end
    "#{a.atom_type.underscore}_#{a.id}"
  end
  
  # Helper for including the nescessary javascripts and stylesheets for the different views.
  # Together with the asset_packager plugin we achieve a lot better load time.
  def wa_assets_set(setname = 'default')
    content_for(:javascript_includes){ javascript_include_merged(setname.to_sym) }
    content_for(:stylesheets){ stylesheet_link_merged(setname.to_sym) }
  end
  
  def parse_sitemap_name(page)
    if multi_language?
      pathname = "/#{session[:language]}/#{page.urlname}"
    else
      pathname = "/#{page.urlname}"
    end
    pathname
  end
  
  def render_new_atom_link(wa_molecule)
    link_to_wa_window(
      _('add new atom'),
      new_wa_molecule_wa_atom_path(wa_molecule),
      {
        :size => '305x40',
        :title => _('Select an atom'),
        :overflow => true
      },
      {
        :id => "add_atom_for_molecule_#{wa_molecule.id}",
        :class => 'button new_atom_link'
      }
    )
  end
  
  def render_create_atom_link(wa_molecule, options = {})
    defaults = {
      :label => _('add new atom')
    }
    options = defaults.merge(options)
    link_to_remote(
      options[:label],
      {
        :url => wa_atoms_path(
          :wa_atom => {
            :name => options[:atom_name],
            :wa_molecule_id => wa_molecule.id
          }
        ),
        :method => 'post'
      },
      {
        :id => "add_atom_for_molecule_#{wa_molecule.id}",
        :class => 'button new_atom_link'
      }
    )
  end
  
  # Returns a icon suitable for a link with css class 'wa_icon_button'
  def wa_icon(icon_class)
    content_tag('span', '', :class => "icon #{icon_class}")
  end
  
end
