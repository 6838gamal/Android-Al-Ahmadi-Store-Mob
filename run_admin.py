import uvicorn

if __name__ == "__main__":
    uvicorn.run(
        "admin_panel.main:app",
        host="0.0.0.0",
        port=8080,
        reload=True,
        proxy_headers=True,
        forwarded_allow_ips="*",
    )
