module assets

// this module provides an AssetManager for combining
// and caching javascript & css.

import (
	os
	time
	crypto.md5
)

const (
	UnknownAssetTypeError = 'vweb.assets: unknown asset type'
)

struct AssetManager {
mut:
	css       []Asset
	js        []Asset
pub:
	// when true assets will be minified
	minify    bool
	// the directory to store the cached/combined files
	cache_dir string 
}

struct Asset {
	file_path     string
	last_modified time.Time
}

// new_manager returns a new AssetManager
pub fn new_manager() *AssetManager {
	return &AssetManager{}
}

// add_css adds a css asset
pub fn (am mut AssetManager) add_css(file string) bool {
	return am.add('css', file)
}

// add_js adds a js asset
pub fn (am mut AssetManager) add_js(file string) bool {
	return am.add('js', file)
}

// combine_css returns the combined css as a string when to_file is false
// when to_file is true it combines the css to disk and returns the path of the file
pub fn (am mut AssetManager) combine_css(to_file bool) string {
	return am.combine('css', to_file)
}

// combine_js returns the combined js as a string when to_file is false
// when to_file is true it combines the css to disk and returns the path of the file
pub fn (am mut AssetManager) combine_js(to_file bool) string {
	return am.combine('js', to_file)
}

// include_css returns the html <link> tag(s) for including the css files in a page.
// when combine is true the files are combined.
pub fn (am mut AssetManager) include_css(combine bool) string {
	return am.include('css', combine)
}

// include_js returns the html <script> tag(s) for including the js files in a page.
// when combine is true the files are combined.
pub fn (am mut AssetManager) include_js(combine bool) string {
	return am.include('js', combine)
}

fn (am mut AssetManager) combine(asset_type string, to_file bool) string {
	if am.cache_dir == '' {
		panic('vweb.assets: you must set a cache dir.')
	}
	cache_key := am.get_cache_key(asset_type)
	out_file := '$am.cache_dir/${cache_key}.$asset_type'
	mut out := ''
	// use cache 
	if os.file_exists(out_file) {
		if to_file {
			return out_file
		}    	
		cached := os.read_file(out_file) or {
			return ''
		}
		return cached
	}
	// rebuild
	for asset in am.get_assets(asset_type) {
		mut data := os.read_file(asset.file_path) or {
			return ''
		}
		out += data
	}
	if am.minify {
		if asset_type == 'css' {
			out = minify_css(out)
		} else {
			out = minify_js(out)
		}
	}
	if !to_file {
		return out
	}
	if !os.dir_exists(am.cache_dir) {
		os.mkdir(am.cache_dir)
	}
	file := os.create(out_file) or {
		panic(err)
	}
	file.write(out)
	file.close()
	return out_file
}

fn (am mut AssetManager) get_cache_key(asset_type string) string {
	mut files_salt := ''
	mut latest_modified := 0
	for asset in am.get_assets(asset_type) {
		files_salt += asset.file_path
		if asset.last_modified.uni > latest_modified {
			latest_modified = asset.last_modified.uni
		}
	}
	hash := md5.sum(files_salt.bytes()).hex()
	return '$hash-$latest_modified'
}

fn (am mut AssetManager) include(asset_type string, combine bool) string {
	assets := am.get_assets(asset_type)
	mut out := ''
	if asset_type == 'css' {
		if combine {
			file := am.combine(asset_type, true)
			return '<link rel="stylesheet" href="$file">\n'
		}
		for asset in assets {
			out += '<link rel="stylesheet" href="$asset.file_path">\n'
		}
	}
	if asset_type == 'js' {
		if combine {
			file := am.combine(asset_type, true)
			return '<script type="text/javascript" src="$file"></script>\n'
		}
		for asset in assets {
			out += '<script type="text/javascript" src="$asset.file_path"></script>\n'
		}
	}
	return out
}

// dont return option until size limit is removed
// fn (am mut AssetManager) add(asset_type, file string) ?bool {
fn (am mut AssetManager) add(asset_type, file string) bool {
	if !os.file_exists(file) {
		// return error('vweb.assets: cannot add asset $file, it does not exist.')
		return false
	}
	asset := Asset{
		file_path: file
		last_modified: time.Time{uni: os.file_last_mod_unix(file)}
	}
	if asset_type == 'css' {
		am.css << asset
	} else if asset_type == 'js' {
		am.js << asset
	} else {
		panic('$UnknownAssetTypeError ($asset_type).')
	}
	return true
}

fn (am mut AssetManager) exists(asset_type, file string) bool {
	assets := am.get_assets(asset_type)
	for asset in assets {
		if asset.file_path == file {
			return true
		}
	}
	return false
}

fn (am mut AssetManager) get_assets(asset_type string) []Asset {
	if asset_type != 'css' && asset_type != 'js' {
		panic('$UnknownAssetTypeError ($asset_type).')
	}
	assets := if asset_type == 'css' {
		am.css
	} else {
		am.js
	}
	return assets
}

// todo: implement proper minification
pub fn minify_css(css string) string {
	mut lines := css.split('\n')
	for i, _ in lines {
		lines[i] = lines[i].trim_space()
	}
	return lines.join(' ')
}

// todo: implement proper minification
pub fn minify_js(js string) string {
	mut lines := js.split('\n')
	for i, _ in lines {
		lines[i] = lines[i].trim_space()
	}
	return lines.join(' ')
}
