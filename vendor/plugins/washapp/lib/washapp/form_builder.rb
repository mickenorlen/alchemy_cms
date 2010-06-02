module Washapp::FormBuilder
  
  # Javascript driven washapp style dropdown selectbox for ActionView::Helpers::FormBuilder objects
  def wa_select(method, values, options = {})
    wa_selectbox(object, method, values, options)
  end

  # returns the html tags and javascript tag for the wa_select form_builder method
  def wa_selectbox(object, method, values, options = {})
    id = [object.class.to_s.underscore, method, 'select'].join('_')
    selected_value = values.detect(){ |v| v[1] == object.send(method) }
    nothing_selected = selected_value.blank?
    if nothing_selected
      if !options[:prompt].blank?
        select_box_content = options[:prompt]
      elsif !options[:include_blank?].blank?
        select_box_content = "&nbsp;"
      else
        select_box_content = values[0][0]
      end
    else
      select_box_content = selected_value[0]
    end
    html = Washapp::ActionView.get_html_scaffold(:prefix, id, select_box_content, '', options)
    unless options[:prompt].blank? || nothing_selected
      html += %(<a href="#" rel="">#{options[:prompt]}</a>)
    end
    values.each do |value|
      selected = (selected_value[1] == value[1] rescue false)
      html += %(
        <a href="#" rel="#{value[1]}" title="#{value[0]}" class="#{selected ? 'selected' : nil}">#{value[0]}</a>
      )
    end
    html += Washapp::ActionView.get_html_scaffold(:suffix, '', '', '')
    html += self.hidden_field(method, :value => (nothing_selected ? values[0][1] : selected_value[1]))
    html += Washapp::ActionView.get_html_scaffold(:js, id, '', [object.class.to_s.underscore, method].join('_'))
    return html
  end

end