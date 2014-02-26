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

try an example command from the help, (list the number of householders age 25-44 with income above $200,000 in Washington State, by congressional district)

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
