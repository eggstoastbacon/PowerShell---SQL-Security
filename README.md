# PowerShell---SQL-Security

First iterations on github may be a little rough as this was written to be used in an environment where I could make some assumptions, and i've had to go through and unindivisualize my code.

This is a script for collecting MSSQL security information such as
.MSSQL Login
.Database Permissions
.Availibility Group, Cluster and Listener Info
.Account is Enabled or Disabled
& More

The default it to write this data into a SQL table. For example I have used this data to build a BI dashboard and used slicers to drill down into dates and servers to see a snapshot of a point in time.

This is also useful for finding and removing users who may have left your org but still have some lingering SQL permissions.

If you have try this let me know if you find any issues in your environment so I can polish this and further generalize it for public use.
