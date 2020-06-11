require 'yaml'
require 'redcarpet'
require './source/util.rb'

def colors
  {
    honoka: 'FF8C00',
    umi: '0000FF',
    kotori: '6B6B6B',
    eli: '87CEEB',
    nozomi: 'BA55D3',
    nico: 'FF69B4',
    maki: 'DC143C',
    rin: 'FFD700',
    hanayo: '32CD32',

    chika: 'FF8000',
    riko: 'FFB6C1',
    you: '00BFFF',
    kanan: '00FA9A',
    mari: '8A2BE2',
    dia: 'FF0000',
    ruby: 'FF1493',
    hanamaru: 'EEC900',
    yohane: '8F8F8F'
  }
end

def get_loc_info(loc)
  @locinfo ||= YAML.load_file('extradata/geocoder_cache.yml')

  @locinfo[loc]
end

def color_of(sym)
  colors[sym] || '000000'
end

def logo(sym)
  span class: "icon-#{sym}"
end

def logoc(sym)
  span class: "icon-#{sym}", style: "color: ##{color_of(sym)}"
end

def standard_page(name:, path:, &block)
  topnav_page path.to_s, name.to_s do
    menu do
      nav 'Home', :home, '/'

      Dir['data/perf/*'].each do |path|
        link_name = path.sub('data/perf/', '')
        slug = link_name.downcase.gsub("µ's", 'muse')
        nav link_name.to_s, :music, "/#{slug}" do
          nav 'Songs', :music, "/#{slug}/songs"
          nav 'Events', :microphone, "/#{slug}/events"
        end
      end
    end

    row do
      col 12 do
        h1 name.to_s
      end
    end

    instance_eval(&block)

    request_css 'css/fonts.css'

    on_page_load <<-SCRIPT
			mixpanel.track("load_page", {name:"#{name}", path:"#{path}"});
    SCRIPT
  end
end

def post_name_to_url_path(md_file)
  md_file.gsub(/-/, '/').gsub(%r{blog/}, '').gsub('.md', '')
end

def render(md_file)
  meta = YAML.load_file(md_file)
  renderer = Redcarpet::Render::HTML.new
  markdown = Redcarpet::Markdown.new(renderer, autolink: true, tables: true)
  content = File.read(md_file).split('---', 2)[1]

  if meta['toppic']
    div align: 'center' do
      image meta['toppic']
    end
    hr
  end

  rendered = markdown.render(content)

  rendered.gsub!(/<img src="(.+?)"/, '<img class="img-responsive" src="/images/\\1"')

  rendered.gsub!(/:(?<name>[a-z]+):/) do |x|
    x.gsub!(':', '')
    "<span class='icon-#{x}' style='color:##{color_of(:"#{x}")}; font-size:1.5em' />"
  end

  text rendered

  if meta['gallery']

    gallery(
      meta['gallery'].map { |x| '/images/' + x },
      meta['gallery'].map { |x| '/images/' + x.sub('.', '-thumb.') }
    )

  end
end
