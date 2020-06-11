def keyize(loc)
  loc.downcase.gsub(/[^0-9a-z]+/, '_').sub(/^_/, '').sub(/_$/, '')
end
