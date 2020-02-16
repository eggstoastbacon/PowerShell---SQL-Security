# PowerShell---SQL-Security

First iterations on github may be a little rough as this was written to be used in an environment where I could make some assumptions, and i've had to go through and generalize my code.

This is a script for collecting MSSQL security information such as;

.MSSQL Login

.Database Permissions

.Availibility Group, Cluster and Listener Info

.Account is Enabled or Disabled

.Account Creation and Modified Date

& More

Designed to be run once per day (day's data will be overwritten if run more than once per day)

The default it to write this data into a SQL table. For example I have used this data to build a BI dashboard and used slicers to drill down into dates and servers to see a snapshot of a point in time.

This is also useful for finding and removing users who may have left your org but still have some lingering SQL permissions.

If you have try this let me know if you find any issues in your environment so I can polish this and further generalize it for public use.

#

Dependencies:

This requires SQL Management Studio is installed from where this is run.

Require WMI and SQL Port access to the servers you will scan.

If scheduled run it only once per day.

Requires sqlserver.psd1 if writing report data to SQL (located in this repo)

