---
title: "1. Improved Inference for Interactive Fixed Effects Model with Cross Sectional Dependence (Job Market Paper)"

# Authors
# If you created a profile for a user (e.g. the default `admin` user), write the username (folder name) here 
# and it will be replaced with their full name and linked to their profile.
authors:
- admin
- Min Seong Kim

# Author notes (optional)
author_notes:
- "Main contributor"
- "Advisor"

# date: "2013-07-01T00:00:00Z"
doi: ""

# Schedule page publish date (NOT publication's date).
publishDate: "2021-09-01T00:00:00Z"

# Publication type.
# Legend: 0 = Uncategorized; 1 = Conference paper; 2 = Journal article;
# 3 = Preprint / Working Paper; 4 = Report; 5 = Book; 6 = Book section;
# 7 = Thesis; 8 = Patent
# publication_types: ["1"]

# Publication name and optional abbreviated publication name.
# publication: In *Wowchemy Conference*
# publication_short: In *ICW*

abstract: In this paper, we propose an improved inference procedure for the interactive fixed effects model in the presence of cross-sectional dependence and heteroskedasticity.  It is well known in the literature that the LS estimator in this model by [Bai (2009)](https://onlinelibrary.wiley.com/doi/10.3982/ECTA6135) is asymptotically biased when the error term is cross-sectionally dependent, and we address this problem. Our procedure involves two parts, correcting the asymptotic bias of the LS estimator and employing the cross-sectional dependence robust covariance matrix estimator. We prove the validity of the proposed procedure in the asymptotic sense. Since our approach is based on the spatial HAC estimation, e.g., [Conley (1999)](https://www.sciencedirect.com/science/article/abs/pii/S0304407698000840), [Kelejian and Prucha (2007)](https://www.sciencedirect.com/science/article/abs/pii/S0304407606002260) and [Kim and Sun (2011)](https://www.sciencedirect.com/science/article/abs/pii/S0304407610002034), we need a distance measure that characterizes the dependence structure. Such a distance may not be available in practice and we address this by considering a data-driven distance that does not rely on prior information. We also develop a bandwidth selection procedure based on a cluster wild bootstrap method. Monte Carlo simulations show our procedure work well in finite samples. As empirical illustrations, we apply the proposed method to make inference on the effects of divorce law reforms on the U.S. divorce rate, and the effects of clean water and sewerage interventions on the U.S. child mortality.




# Summary. An optional shortened abstract.
# summary: 

tags: 
url_pdf: 'JMP_Zhenhao.pdf'
url_code: 'IFE_SHAC.R'
url_slides: 'Slides.pdf'

# Display this page in the Featured widget?
featured: false

# Custom links (uncomment lines below)
# links:
# - name: Custom Link
#   url: http://example.org

url_pdf: 'JMP_Zhenhao.pdf'
url_code: 'IFE_SHAC.R'
# url_dataset: ''
# url_poster: ''
# url_project: ''
url_slides: 'Slides.pdf'
# url_source: ''
# url_video: ''

# Featured image
# To use, add an image named `featured.jpg/png` to your page's folder. 
# image:
#   caption: 'Image credit: [**Unsplash**](https://unsplash.com/photos/pLCdAaMFLTE)'
#   focal_point: ""
#   preview_only: false

# Associated Projects (optional).
#   Associate this publication with one or more of your projects.
#   Simply enter your project's folder or file name without extension.
#   E.g. `internal-project` references `content/project/internal-project/index.md`.
#   Otherwise, set `projects: []`.
#projects:
#- example

# Slides (optional).
#   Associate this publication with Markdown slides.
#   Simply enter your slide deck's filename without extension.
#   E.g. `slides: "example"` references `content/slides/example/index.md`.
#   Otherwise, set `slides: ""`.
# slides: example
---
