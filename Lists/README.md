# Examples using Lists

## [Installomator](https://github.com/Installomator/Installomator)

The `dialog-installomator.sh` script will display a dialog with a list of labels matching installomator labels and install them one at a time providing progress.

### Use

Update the `labels` array with the desired software labels

```bash
labels=(
    "googlechrome"
    "audacity"
    "firefox"
    "inkscape"
)
```

update the installomator script path

`installomator="/path/to/Installomator.sh"`

![image](https://user-images.githubusercontent.com/3598965/152978464-1b602a68-da97-431a-8f79-1d899cb4fccb.png)
