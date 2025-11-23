# Color Fill App



## Inspiration
I watched a person on a Jetblue flight,  use a color by number app on their iphone. This is the first time, I had seen one like that

The color(on long tap)spilled into the numbered region. And these were complex paintings as well, it wasn't just one color but the split was unique enough to accomodate complex gradients and shades


### Flow breakdown

This is a quick flow

1. Designing the sketch
2. Then come up with regions
3. Number selected regions
4. Allow user to fill color in said region (suggest the right one/allow picking from a color palette)


### Project Notes

As a flutter developer, I tried to replicate this with a sample image loaded from assets, Its just one image right now


The simplest thing I'd suggest trying is to tweak the value of the '**threshold**' variable and you could try this on various image to see how you could better it


### Images
Original and Regions Detected            |  Rendered Fillable Image
:-------------------------:|:-------------------------:
![image](https://github.com/user-attachments/assets/5d2f784f-b4e1-44ec-9d70-cbda2dd893e2) | ![image](https://github.com/user-attachments/assets/fc6f8908-c01a-4c8a-a047-62f3181dae36)




### Regrets

1. I can't make the edges smooth
2. There is no conclusive value of threshold I can set to make this look as sharp as the coloring by numbers app that I saw
