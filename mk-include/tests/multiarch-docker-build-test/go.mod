module github.com/confluentinc/cc-test-service

require (
	github.com/sirupsen/logrus v1.4.2
	github.com/stretchr/testify v1.3.0
)

require golang.org/x/sys v0.0.0-20220412211240-33da011f77ad // indirect

replace golang.org/x/sys => golang.org/x/sys v0.0.0-20220412211240-33da011f77ad

go 1.19
