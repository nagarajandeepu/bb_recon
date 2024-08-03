#!/bin/bash

# Check for domains.txt
if [ ! -f "domains.txt" ]; then
    echo "domains.txt not found! Please create a file named 'domains.txt' with one domain per line."
    exit 1
fi

# Create a logs directory
mkdir -p logs

# Read domains from the input file
while read -r domain; do
    # Current date and time
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Create a directory for the domain
    mkdir -p "$domain"
    
    # Log file for this domain
    log_file="logs/${domain}_log_$(date "+%Y%m%d_%H%M%S").log"
    touch "$log_file"
    
    echo "$timestamp: Processing $domain" | tee -a "$log_file"
    
    # 1. Crawl Main Domains
    echo "$timestamp: Crawling main domain: $domain" | tee -a "$log_file"
    
    # Katana
    katana -u http://$domain -depth 5 -o "$domain/katana_$domain.txt" 2>>"$log_file"
    echo "$timestamp: Katana finished" | tee -a "$log_file"
    
    # Hakrawler
    $domain | hakrawler -depth 5 > "$domain/hakrawler_$domain.txt" 2>>"$log_file"
    echo "$timestamp: Hakrawler finished" | tee -a "$log_file"
    
    # GetAllURLs
    $domain | getallurls > "$domain/getallurls_$domain.txt" 2>>"$log_file"
    echo "$timestamp: GetAllURLs finished" | tee -a "$log_file"
    
    # 2. Aggregate Data from All Files
    echo "$timestamp: Aggregating data from all files..." | tee -a "$log_file"
    cat "$domain/katana_$domain.txt" "$domain/hakrawler_$domain.txt" "$domain/getallurls_$domain.txt" > "$domain/combined_results_$domain.txt"
    grep -Eo 'http[s]?://[^ ]+' "$domain/combined_results_$domain.txt" > "$domain/all_urls_$domain.txt"
    
    # Remove duplicates and ensure URLs are alive
    sort -u "$domain/all_urls_$domain.txt" | while read -r url; do
        if curl -s --head "$url" | head -n 1 | grep "200 OK" > /dev/null; then
            echo "$url" >> "$domain/valid_urls_$domain.txt"
        fi
    done
    
    echo "$timestamp: URL validation finished" | tee -a "$log_file"
    
    # Clean Data
    echo "$timestamp: Cleaning Data..." | tee -a "$log_file"
    grep -E '(\?|\&)[^\?]*=.*' "$domain/valid_urls_$domain.txt" > "$domain/vulnerable_parameters_$domain.txt"
    grep -E '\.js' "$domain/valid_urls_$domain.txt" > "$domain/js_files_$domain.txt"
    grep -v -E '(\?|\&)[^\?]*=.*|\.js' "$domain/valid_urls_$domain.txt" > "$domain/other_links_$domain.txt"
    
    # 3. Subdomain Enumeration
    echo "$timestamp: Enumerating subdomains for $domain" | tee -a "$log_file"
    
    # Sublist3r
    sublist3r -d $domain -o "$domain/sublist3r_$domain.txt" 2>>"$log_file"
    echo "$timestamp: Sublist3r finished" | tee -a "$log_file"
    
    # Amass Enum
    amass enum -d $domain -o "$domain/amass_$domain.txt" 2>>"$log_file"
    echo "$timestamp: Amass Enum finished" | tee -a "$log_file"
    
    # Amass Intel
    amass intel -whois -d $domain -o "$domain/amass_intel_$domain.txt" 2>>"$log_file"
    echo "$timestamp: Amass Intel finished" | tee -a "$log_file"
    
    # Subfinder
    subfinder -d $domain -all -o "$domain/subfinder_$domain.txt" 2>>"$log_file"
    echo "$timestamp: Subfinder finished" | tee -a "$log_file"
    
    # Knockpy
    knockpy $domain -o "$domain/knockpy_$domain.txt" 2>>"$log_file"
    echo "$timestamp: Knockpy finished" | tee -a "$log_file"
    
    # DNSenum
    dnsenum $domain -d --noreverse -o "$domain/dnsenum_$domain.txt" 2>>"$log_file"
    echo "$timestamp: DNSenum finished" | tee -a "$log_file"
    
    # Findomain
    findomain -t $domain -u "$domain/findomain_$domain.txt" 2>>"$log_file"
    echo "$timestamp: Findomain finished" | tee -a "$log_file"
    
    # 4. Aggregate Subdomains Data
    echo "$timestamp: Aggregating subdomains data..." | tee -a "$log_file"
    cat "$domain/sublist3r_$domain.txt" "$domain/amass_$domain.txt" "$domain/amass_intel_$domain.txt" "$domain/subfinder_$domain.txt" "$domain/knockpy_$domain.txt" "$domain/dnsenum_$domain.txt" "$domain/findomain_$domain.txt" > "$domain/all_subdomains_$domain.txt"
    sort -u "$domain/all_subdomains_$domain.txt" > "$domain/unique_subdomains_$domain.txt"
    
    # 5. GetAllURLs for Subdomains
    echo "$timestamp: Getting all URLs for subdomains..." | tee -a "$log_file"
    while read -r subdomain; do
        getallurls -u http://$subdomain -o "$domain/getallurls_subdomains_$subdomain.txt" 2>>"$log_file"
    done < "$domain/unique_subdomains_$domain.txt"
    
    # 6. Crawl Subdomains
    echo "$timestamp: Crawling subdomains..." | tee -a "$log_file"
    while read -r subdomain; do
        katana -u http://$subdomain -depth 5 -o "$domain/katana_subdomain_$subdomain.txt" 2>>"$log_file"
    done < "$domain/unique_subdomains_$domain.txt"
    
    # 7. Check for Subdomain Takeover
    echo "$timestamp: Checking for subdomain takeover..." | tee -a "$log_file"
    subjack -w "$domain/unique_subdomains_$domain.txt" -t 100 -timeout 30 -o "$domain/subdomain_takeover_$domain.txt" -ssl 2>>"$log_file"
    echo "$timestamp: Subdomain takeover check completed" | tee -a "$log_file"
    
    # Generate report for subdomain takeovers
    if [ -s "$domain/subdomain_takeover_$domain.txt" ]; then
        echo "$timestamp: Subdomain Takeover Vulnerabilities found. See $domain/subdomain_takeover_$domain.txt for details." | tee -a "$log_file"
    else
        echo "$timestamp: No Subdomain Takeover Vulnerabilities found." | tee -a "$log_file"
    fi
    
    # Final Time Summary for the Domain
    echo "$timestamp: Processing for $domain completed." | tee -a "$log_file"

done < "domains.txt"
