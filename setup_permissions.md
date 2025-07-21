# Setting up Full Disk Access for Klinmai

To avoid repeated permission dialogs, grant Klinmai Full Disk Access:

## Steps:

1. Open **System Settings** (or System Preferences on older macOS)

2. Click on **Privacy & Security** in the sidebar

3. In the Privacy section, scroll down and click on **Full Disk Access**

4. Click the **+** button to add an application

5. Navigate to where Klinmai is installed:
   - If running from Xcode: `/Users/jade/Library/Developer/Xcode/DerivedData/` (find the Klinmai folder)
   - If running from command line: `/Users/jade/Klinmai/.build/debug/Klinmai`
   - If installed as an app: `/Applications/Klinmai.app`

6. Select **Klinmai** and click **Open**

7. Make sure the toggle next to Klinmai is **ON**

8. You may need to quit and restart Klinmai for the changes to take effect

## Alternative: Files and Folders Access

If you don't want to grant Full Disk Access, you can grant specific folder access:

1. In Privacy & Security, click on **Files and Folders**
2. Find Klinmai in the list
3. Enable access for:
   - Desktop Folder
   - Documents Folder
   - Downloads Folder
   - iCloud Drive
   - Removable Volumes

This will prevent the permission dialogs from appearing repeatedly.