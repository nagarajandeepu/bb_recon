#!/bin/bash

# Sample settings
GO_SPIDER_DEPTH=5

# Check for domains.txt
if [ ! -f "domains.txt" ]; then
    echo "domains.txt not found! Please create a file named 'domains.txt' with one domain per line."
    exit 1
fi

# Read domains from the input file
while read -r domain; do
    # Create a log directory for the domain
    LOG_DIR="logs/$domain"
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/bug_bounty_$domain.log"
    echo "Processing $domain" | tee -a "$LOG_FILE"

    start_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "Start Time: $start_time" | tee -a "$LOG_FILE"

    # 1. Crawl Main Domains
    echo "Crawling main domain: $domain" | tee -a "$LOG_FILE"

    # Katana
    echo "Running Katana..." | tee -a "$LOG_FILE"
    start_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "Katana Start Time: $start_time" | tee -a "$LOG_FILE"
    katana -u http://$domain -depth $GO_SPIDER_DEPTH -o "$LOG_DIR/katana_$domain.txt" 2>> "$LOG_DIR/katana_error.log" || {
        echo "Katana encountered an error. Check $LOG_DIR/katana_error.log for details." | tee -a "$LOG_FILE"
    }
    end_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "Katana End Time: $end_time" | tee -a "$LOG_FILE"
    duration=$((($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s))))
    echo "Katana Duration: $((duration / 60)) minutes and $((duration % 60)) seconds" | tee -a "$LOG_FILE"

    # Hakrawler
    echo "Running Hakrawler..." | tee -a "$LOG_FILE"
    start_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "Hakrawler Start Time: $start_time" | tee -a "$LOG_FILE"
    hakrawler -url http://$domain -depth 5 -plain > "$LOG_DIR/hakrawler_$domain.txt" 2>> "$LOG_DIR/hakrawler_error.log" || {
        echo "Hakrawler encountered an error. Check $LOG_DIR/hakrawler_error.log for details." | tee -a "$LOG_FILE"
    }
    end_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "Hakrawler End Time: $end_time" | tee -a "$LOG_FILE"
    duration=$((($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s))))
    echo "Hakrawler Duration: $((duration / 60)) minutes and $((duration % 60)) seconds" | tee -a "$LOG_FILE"

    # GetAllURLs
    echo "Running GetAllURLs..." | tee -a "$LOG_FILE"
    start_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "GetAllURLs Start Time: $start_time" | tee -a "$LOG_FILE"
    getallurls -u http://$domain -o "$LOG_DIR/getallurls_$domain.txt" 2>> "$LOG_DIR/getallurls_error.log" || {
        echo "GetAllURLs encountered an error. Check $LOG_DIR/getallurls_error.log for details." | tee -a "$LOG_FILE"
    }
    end_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "GetAllURLs End Time: $end_time" | tee -a "$LOG_FILE"
    duration=$((($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s))))
    echo "GetAllURLs Duration: $((duration / 60)) minutes and $((duration % 60)) seconds" | tee -a "$LOG_FILE"

    # 2. Aggregate Data from All Files
    echo "Aggregating data from all files..." | tee -a "$LOG_FILE"
    start_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "Data Aggregation Start Time: $start_time" | tee -a "$LOG_FILE"
    cat "$LOG_DIR/katana_$domain.txt" "$LOG_DIR/hakrawler_$domain.txt" "$LOG_DIR/getallurls_$domain.txt" > "$LOG_DIR/combined_results_$domain.txt"
    grep -Eo 'http[s]?://[^ ]+' "$LOG_DIR/combined_results_$domain.txt" | tee "$LOG_DIR/all_urls_$domain.txt"
    end_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "Data Aggregation End Time: $end_time" | tee -a "$LOG_FILE"
    duration=$((($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s))))
    echo "Data Aggregation Duration: $((duration / 60)) minutes and $((duration % 60)) seconds" | tee -a "$LOG_FILE"

    # Remove duplicates and ensure URLs are alive
    echo "Filtering and checking URLs..." | tee -a "$LOG_FILE"
    start_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "URL Filtering Start Time: $start_time" | tee -a "$LOG_FILE"
    sort -u "$LOG_DIR/all_urls_$domain.txt" | while read -r url; do
        if curl -s --head "$url" | head -n 1 | grep "200 OK" > /dev/null; then
            echo "$url" >> "$LOG_DIR/valid_urls_$domain.txt"
        fi
    done
    end_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "URL Filtering End Time: $end_time" | tee -a "$LOG_FILE"
    duration=$((($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s))))
    echo "URL Filtering Duration: $((duration / 60)) minutes and $((duration % 60)) seconds" | tee -a "$LOG_FILE"

    # Clean Data
    echo "Cleaning Data..." | tee -a "$LOG_FILE"
    start_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "Data Cleaning Start Time: $start_time" | tee -a "$LOG_FILE"
    grep -E '(\?|\&)[^\?]*=.*' "$LOG_DIR/valid_urls_$domain.txt" | tee "$LOG_DIR/vulnerable_parameters_$domain.txt"
    grep -E '\.js' "$LOG_DIR/valid_urls_$domain.txt" | tee "$LOG_DIR/js_files_$domain.txt"
    grep -v -E '(\?|\&)[^\?]*=.*|\.js' "$LOG_DIR/valid_urls_$domain.txt" | tee "$LOG_DIR/other_links_$domain.txt"
    end_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "Data Cleaning End Time: $end_time" | tee -a "$LOG_FILE"
    duration=$((($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s))))
    echo "Data Cleaning Duration: $((duration / 60)) minutes and $((duration % 60)) seconds" | tee -a "$LOG_FILE"

    # 3. Subdomain Enumeration
    echo "Enumerating subdomains for $domain" | tee -a "$LOG_FILE"
    start_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "Subdomain Enumeration Start Time: $start_time" | tee -a "$LOG_FILE"

    # Sublist3r
    echo "Running Sublist3r..." | tee -a "$LOG_FILE"
    sublist3r -d $domain -o "$LOG_DIR/sublist3r_$domain.txt" 2>> "$LOG_DIR/sublist3r_error.log" || {
        echo "Sublist3r encountered an error. Check $LOG_DIR/sublist3r_error.log for details." | tee -a "$LOG_FILE"
    }

    # Amass Enum
    echo "Running Amass Enum..." | tee -a "$LOG_FILE"
    amass enum -d $domain -o "$LOG_DIR/amass_$domain.txt" 2>> "$LOG_DIR/amass_enum_error.log" || {
        echo "Amass Enum encountered an error. Check $LOG_DIR/amass_enum_error.log for details." | tee -a "$LOG_FILE"
    }

    # Amass Intel
    echo "Running Amass Intel..." | tee -a "$LOG_FILE"
    amass intel -d $domain -o "$LOG_DIR/amass_intel_$domain.txt" 2>> "$LOG_DIR/amass_intel_error.log" || {
        echo "Amass Intel encountered an error. Check $LOG_DIR/amass_intel_error.log for details." | tee -a "$LOG_FILE"
    }

    # Subfinder
    echo "Running Subfinder..." | tee -a "$LOG_FILE"
    subfinder -d $domain -o "$LOG_DIR/subfinder_$domain.txt" 2>> "$LOG_DIR/subfinder_error.log" || {
        echo "Subfinder encountered an error. Check $LOG_DIR/subfinder_error.log for details." | tee -a "$LOG_FILE"
    }

    # Knockpy
    echo "Running Knockpy..." | tee -a "$LOG_FILE"
    knockpy $domain -o "$LOG_DIR/knockpy_$domain.txt" 2>> "$LOG_DIR/knockpy_error.log" || {
        echo "Knockpy encountered an error. Check $LOG_DIR/knockpy_error.log for details." | tee -a "$LOG_FILE"
    }

    # DNSenum
    echo "Running DNSenum..." | tee -a "$LOG_FILE"
    dnsenum $domain -d --noreverse -o "$LOG_DIR/dnsenum_$domain.txt" 2>> "$LOG_DIR/dnsenum_error.log" || {
        echo "DNSenum encountered an error. Check $LOG_DIR/dnsenum_error.log for details." | tee -a "$LOG_FILE"
    }

    # Findomain
    echo "Running Findomain..." | tee -a "$LOG_FILE"
    findomain -t $domain -u "$LOG_DIR/findomain_$domain.txt" 2>> "$LOG_DIR/findomain_error.log" || {
        echo "Findomain encountered an error. Check $LOG_DIR/findomain_error.log for details." | tee -a "$LOG_FILE"
    }

    end_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "Subdomain Enumeration End Time: $end_time" | tee -a "$LOG_FILE"
    duration=$((($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s))))
    echo "Subdomain Enumeration Duration: $((duration / 60)) minutes and $((duration % 60)) seconds" | tee -a "$LOG_FILE"

    # 4. Aggregate Subdomains Data
    echo "Aggregating subdomains data..." | tee -a "$LOG_FILE"
    start_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "Subdomains Data Aggregation Start Time: $start_time" | tee -a "$LOG_FILE"
    cat "$LOG_DIR/sublist3r_$domain.txt" "$LOG_DIR/amass_$domain.txt" "$LOG_DIR/amass_intel_$domain.txt" "$LOG_DIR/subfinder_$domain.txt" "$LOG_DIR/knockpy_$domain.txt" "$LOG_DIR/dnsenum_$domain.txt" "$LOG_DIR/findomain_$domain.txt" > "$LOG_DIR/all_subdomains_$domain.txt"
    sort -u "$LOG_DIR/all_subdomains_$domain.txt" > "$LOG_DIR/unique_subdomains_$domain.txt"
    end_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "Subdomains Data Aggregation End Time: $end_time" | tee -a "$LOG_FILE"
    duration=$((($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s))))
    echo "Subdomains Data Aggregation Duration: $((duration / 60)) minutes and $((duration % 60)) seconds" | tee -a "$LOG_FILE"

    # 5. GetAllURLs for Subdomains
    echo "Getting all URLs for subdomains..." | tee -a "$LOG_FILE"
    start_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "GetAllURLs for Subdomains Start Time: $start_time" | tee -a "$LOG_FILE"
    while read -r subdomain; do
        echo "Getting all URLs for subdomain: $subdomain" | tee -a "$LOG_FILE"

        # GetAllURLs
        getallurls -u http://$subdomain -o "$LOG_DIR/getallurls_subdomains_$subdomain.txt" 2>> "$LOG_DIR/getallurls_subdomains_error.log" || {
            echo "GetAllURLs encountered an error for $subdomain. Check $LOG_DIR/getallurls_subdomains_error.log for details." | tee -a "$LOG_FILE"
        }
    done < "$LOG_DIR/unique_subdomains_$domain.txt"
    end_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "GetAllURLs for Subdomains End Time: $end_time" | tee -a "$LOG_FILE"
    duration=$((($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s))))
    echo "GetAllURLs for Subdomains Duration: $((duration / 60)) minutes and $((duration % 60)) seconds" | tee -a "$LOG_FILE"

    # 6. Crawl Subdomains
    echo "Crawling subdomains..." | tee -a "$LOG_FILE"
    start_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "Crawling Subdomains Start Time: $start_time" | tee -a "$LOG_FILE"
    while read -r subdomain; do
        echo "Crawling subdomain: $subdomain" | tee -a "$LOG_FILE"

        # Katana
        echo "Running Katana for subdomain..." | tee -a "$LOG_FILE"
        start_time=$(date +'%Y-%m-%d %H:%M:%S')
        echo "Katana Start Time: $start_time" | tee -a "$LOG_FILE"
        katana -u http://$subdomain -depth $GO_SPIDER_DEPTH -o "$LOG_DIR/katana_subdomain_$subdomain.txt" 2>> "$LOG_DIR/katana_subdomain_error.log" || {
            echo "Katana encountered an error for $subdomain. Check $LOG_DIR/katana_subdomain_error.log for details." | tee -a "$LOG_FILE"
        }
        end_time=$(date +'%Y-%m-%d %H:%M:%S')
        echo "Katana End Time: $end_time" | tee -a "$LOG_FILE"
        duration=$((($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s))))
        echo "Katana Duration: $((duration / 60)) minutes and $((duration % 60)) seconds" | tee -a "$LOG_FILE"

    done < "$LOG_DIR/unique_subdomains_$domain.txt"
    end_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "Crawling Subdomains End Time: $end_time" | tee -a "$LOG_FILE"
    duration=$((($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s))))
    echo "Crawling Subdomains Duration: $((duration / 60)) minutes and $((duration % 60)) seconds" | tee -a "$LOG_FILE"

    # Final Time Summary for the Domain
    end_time=$(date +'%Y-%m-%d %H:%M:%S')
    echo "Domain Processing End Time: $end_time" | tee -a "$LOG_FILE"
    total_duration=$((($(date -d "$end_time" +%s) - $(date -d "$start_time" +%s))))
    echo "Total Processing Duration for $domain: $((total_duration / 60)) minutes and $((total_duration % 60)) seconds" | tee -a "$LOG_FILE"

done < "domains.txt"


