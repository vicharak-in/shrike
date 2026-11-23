# -- Project information -----------------------------------------------------
project = 'Shrike'
author = 'Deepak Sharda'
release = '1.0'
html_title = "Shrike Documentation"

# -- General configuration ---------------------------------------------------
extensions = [
    'myst_parser',
    'sphinx.ext.autosectionlabel',
    'sphinx.ext.todo',
    'sphinx.ext.mathjax',
    "sphinx_design",
]

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

# Support both .rst and .md files
source_suffix = {
    '.rst': 'restructuredtext',
    '.md': 'markdown',
}

# Set the main page (your entry point)
master_doc = 'index'

# -- Extension configuration -------------------------------------------------
autosectionlabel_prefix_document = True
autosectionlabel_maxdepth = 2

myst_enable_extensions = [
    "html_admonition",
    "html_image",
    "colon_fence",
]
myst_heading_anchors = 3

# -- Options for HTML output -------------------------------------------------
html_theme = 'sphinxawesome_theme'

html_extra_path = ['images']

# -- Theme options -----------------------------------------------------------
html_theme_options = {
    "show_prev_next": True,
    "show_breadcrumbs": True,
}
