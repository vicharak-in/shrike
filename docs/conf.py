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

# -- Options for HTML output -------------------------------------------------
html_theme = 'sphinxawesome_theme'

html_extra_path = ['images']

# -- Theme options -----------------------------------------------------------
html_theme_options = {
    "logo_text": "Shrike",
    "show_prev_next": True,
    "show_breadcrumbs": True,
    "show_sidebar": True,
}

myst_enable_extensions = ["html_admonition", "html_image", "colon_fence"]


# -- Optional: enable dark/light toggle ------------------------------------