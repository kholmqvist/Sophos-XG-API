# Sophos-XG-API
TL;DR. Add a lists of IP or Network addresses from a CSV file to Sophos Firewall. 

I had a usecase where I needed to limit access to a API endpoint in my Sophos Firewall WAF. The IP addresses allowed to access the API was all from Microsoft and there was a lot of both IP addresses and network addresses to be added, so instead of manually creating the host objects in Sophos Firewall i decided to use their API.

1. Create a Device Access profile and a API user in Sophos Firewall.
![device profile](./assets/images/Device-Profile.png)
![api user](./assets/images/API-User.png)

2. Allow API access from your local IP address
![api](./assets/images/Enable-API.png)

I added all the Microsoft IPs in the ip.csv file and then created a IP Host Group called ***MS Graph Notifications*** manually in Sophos Firewall. I then ran my script which loops through all the addresses in the CSV file and add the host objects to my HostGroup object
