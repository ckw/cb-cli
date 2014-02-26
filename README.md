cb-cli
======

A command line interface to the US Census Bureau's [public api](https://www.census.gov/developers)

To install, you'll need

* ruby, probably 1.9+; it's untested on earlier versions
* curl
* an api key (get one [here](https://www.census.gov/developers/tos/key_request.html))
* bundler (optional)

clone this repository
```
git clone git@github.com:ckw/cb-cli.git
cd cb-cli
```

if you have bundler, then

```
bundle install
```

if you don't

```
gem install cli_utils
```

put a symlink to the script in your path, e.g.,

```
sudo ln -s ~/cb-cli/cb-cli.rb /usr/local/bin/cb-cli
```

take a look at the help

```
cb-cli
```

Try an example command from the help, (list the number of householders age 25-44 with income above $200,000 in Washington State, by congressional district)

```
cb-cli acs1-2012 "NAME,B19037_035E" "congressional+district:*" --in "state:53"
```

At the first invocation of a command requiring an api key you will be prompted
for one. To change the key later, edit the config file

```
cb-cli edit-config
```

At the moment, it should look like

```yaml
defaults:
  api_key: your_key_goes_here
```

###Notes

* Most commands are automatically generated with the use of the [discovery file](http://api.census.gov/data.json)

* Variable and geography files for each dataset are lazily cached locally.

* To update the commands, in the event that the CB adds more datasets, run

```
cb-cli update-commands
```

* To update the commands as well as all other files, run

```
cb-cli refresh-all-caches
```

* To get a detailed description of each autogenerated command, run

```
cb-cli describe-command <name_of_command>
```

For example, `cb-cli dc acs1-2012` will output something similar to

> The American Community Survey (ACS) is a nationwide survey designed to provide
communities a fresh look at how they are changing. The ACS replaced the
decennial census long form in 2010 and thereafter by collecting long form type
information throughout the decade rather than only once every 10 years.
Questionnaires are mailed to a sample of addresses to obtain information about
households -- that is, about each person and the housing unit itself.  The
American Community Survey produces demographic, social, housing and economic
estimates in the form of 1-year, 3-year and 5-year estimates based on
population thresholds. The strength of the ACS is in estimating population and
housing characteristics. It produces estimates for small areas, including
census tracts and population subgroups.  Although the ACS produces population,
demographic and housing unit estimates,it is the Census Bureau's Population
Estimates Program that produces and disseminates the official estimates of the
population for the nation, states, counties, cities and towns, and estimates of
housing units for states and counties.  For 2010 and other decennial census
years, the Decennial Census provides the official counts of population and
housing units.
